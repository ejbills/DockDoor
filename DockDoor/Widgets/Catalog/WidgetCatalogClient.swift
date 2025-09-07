import CryptoKit
import Foundation

/// Lightweight client that loads a remote catalog JSON with local caching and TTL.
/// Network fetch is pluggable; for development, a file:// URL can be used.
final class WidgetCatalogClient {
    static let shared = WidgetCatalogClient()

    // Default cache path: ~/Library/Application Support/DockDoor/WidgetCatalog/cache.json
    private var cacheURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("DockDoor/WidgetCatalog/cache.json")
    }

    // TTL in seconds for catalog cache
    var ttlSeconds: TimeInterval = 60 * 60 // 1 hour

    // Public key for signature verification (Ed25519). Set via configuration.
    // Store as raw 32-byte key data in Base64.
    var publicKeyBase64: String?

    private init() {}

    // Load catalog with caching. If `forceRefresh` is true, skip cache TTL.
    func loadCatalog(from url: URL, forceRefresh: Bool = false) async throws -> WidgetCatalog {
        if let cached = try? loadCachedCatalog(), !forceRefresh {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
               let modified = attrs[.modificationDate] as? Date,
               Date().timeIntervalSince(modified) < ttlSeconds
            {
                return cached
            }
        }

        // Fetch
        let data: Data
        if url.isFileURL {
            data = try Data(contentsOf: url)
        } else {
            // For sandboxed/no-network contexts, this branch must be handled by host app.
            // Here we synchronously attempt a URLSession fetch.
            let (fetched, _) = try await URLSession.shared.data(from: url)
            data = fetched
        }
        let catalog = try JSONDecoder().decode(WidgetCatalog.self, from: data)
        try persistCache(data: data)
        return catalog
    }

    func loadCachedCatalog() throws -> WidgetCatalog? {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        let data = try Data(contentsOf: cacheURL)
        let catalog = try JSONDecoder().decode(WidgetCatalog.self, from: data)
        return catalog
    }

    private func persistCache(data: Data) throws {
        let dir = cacheURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: cacheURL, options: .atomic)
    }

    // MARK: - Signature & Hash Verification

    func verifySignature(data: Data, signatureBase64: String) -> Bool {
        guard let keyB64 = publicKeyBase64,
              let keyData = Data(base64Encoded: keyB64),
              let sigData = Data(base64Encoded: signatureBase64) else { return false }
        do {
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
            return publicKey.isValidSignature(sigData, for: data)
        } catch {
            return false
        }
    }

    func computeSHA256Hex(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
