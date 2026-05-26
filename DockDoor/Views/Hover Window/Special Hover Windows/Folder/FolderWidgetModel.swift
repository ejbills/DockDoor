import AppKit
import Defaults
import Foundation

struct FolderWidgetItem: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let modifiedDate: Date
    let size: Int64
    let localizedKind: String

    var id: String { url.path }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

enum FolderWidgetAccessState: Equatable {
    case loading
    case accessible([FolderWidgetItem])
    case permissionDenied
    case missing
    case failed
}

enum FolderWidgetLoader {
    static func loadItems(from url: URL, showHiddenFiles: Bool) async -> FolderWidgetAccessState {
        await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default

            guard fileManager.fileExists(atPath: url.path) else {
                return .missing
            }

            let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [] : [.skipsHiddenFiles]

            do {
                let urls = try fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [
                        .isDirectoryKey,
                        .contentModificationDateKey,
                        .fileSizeKey,
                        .totalFileAllocatedSizeKey,
                        .localizedTypeDescriptionKey,
                    ],
                    options: options
                )

                let items = urls.compactMap { itemURL -> FolderWidgetItem? in
                    let values = try? itemURL.resourceValues(forKeys: [
                        .isDirectoryKey,
                        .contentModificationDateKey,
                        .fileSizeKey,
                        .totalFileAllocatedSizeKey,
                        .localizedTypeDescriptionKey,
                    ])

                    return FolderWidgetItem(
                        url: itemURL,
                        name: itemURL.lastPathComponent,
                        isDirectory: values?.isDirectory ?? false,
                        modifiedDate: values?.contentModificationDate ?? .distantPast,
                        size: Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0),
                        localizedKind: values?.localizedTypeDescription ?? ""
                    )
                }

                return .accessible(items)
            } catch let error as NSError where error.code == NSFileReadNoPermissionError {
                return .permissionDenied
            } catch {
                return .failed
            }
        }.value
    }
}

enum FolderWidgetAuthorization {
    static func accessibleURL(for url: URL) -> URL? {
        if let bookmarkedURL = resolvedAuthorizedURL(for: url), canRead(bookmarkedURL) {
            return bookmarkedURL
        }

        if canRead(url) {
            return url
        }

        return nil
    }

    @MainActor
    static func requestAccess(to url: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.message = String(localized: "Choose this folder to let DockDoor show its contents.")
        panel.prompt = String(localized: "Allow Access")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = url.deletingLastPathComponent()

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return nil }
        guard selectedURL.standardizedFileURL == url.standardizedFileURL else { return nil }

        if let bookmark = try? selectedURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            var bookmarks = Defaults[.folderWidgetAuthorizedBookmarks]
            bookmarks[url.path] = bookmark.base64EncodedString()
            Defaults[.folderWidgetAuthorizedBookmarks] = bookmarks
        }

        return selectedURL
    }

    static func resolvedAuthorizedURL(for url: URL) -> URL? {
        guard let encoded = Defaults[.folderWidgetAuthorizedBookmarks][url.path],
              let data = Data(base64Encoded: encoded)
        else { return nil }

        var isStale = false
        return try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    private static func canRead(_ url: URL) -> Bool {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            _ = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return true
        } catch {
            return false
        }
    }
}
