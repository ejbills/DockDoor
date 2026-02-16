import Cocoa
import Defaults

enum ChromiumBrowser: String, CaseIterable, Defaults.Serializable {
    case chrome
    case chromium

    var displayName: String {
        switch self {
        case .chrome: "Google Chrome"
        case .chromium: "Chromium"
        }
    }

    var bundleID: String {
        switch self {
        case .chrome: "com.google.Chrome"
        case .chromium: "org.chromium.Chromium"
        }
    }

    private var dataDirectory: String {
        switch self {
        case .chrome: "Google/Chrome"
        case .chromium: "Chromium"
        }
    }

    var localStatePath: String {
        "~/Library/Application Support/\(dataDirectory)/Local State"
    }
}

enum ChromiumProfileResolver {
    /// Returns the profile icon for a Chromium browser window when multiple profiles are active, or nil otherwise.
    static func profileIcon(forWindowTitle title: String, bundleIdentifier: String) -> NSImage? {
        guard Defaults[.showBrowserProfileBadge] else { return nil }

        let browser = Defaults[.selectedChromiumBrowser]
        guard bundleIdentifier == browser.bundleID else { return nil }

        let profiles = loadProfiles(for: browser)
        guard profiles.count >= 2 else { return nil }

        // Multi-profile title format: "Tab Title - Browser Name - Profile Name"
        let browserMarker = " - \(browser.displayName)"
        guard let markerRange = title.range(of: browserMarker, options: .backwards) else { return nil }

        let afterMarker = title[markerRange.upperBound...]
        guard afterMarker.hasPrefix(" - ") else { return nil }

        let candidateProfile = String(afterMarker.dropFirst(3))
        return profiles[candidateProfile]
    }

    private static func loadProfiles(for browser: ChromiumBrowser) -> [String: NSImage] {
        let expandedPath = NSString(string: browser.localStatePath).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        let browserDir = url.deletingLastPathComponent().path

        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: Any]
        else { return [:] }

        var result: [String: NSImage] = [:]
        for (dirName, value) in infoCache {
            guard let profileDict = value as? [String: Any],
                  let name = profileDict["name"] as? String
            else { continue }

            let picturePath = "\(browserDir)/\(dirName)/Google Profile Picture.png"
            guard let icon = NSImage(contentsOfFile: picturePath) else { continue }

            // Chromium uses gaia_given_name in window titles when signed into Google
            let gaiaGivenName = profileDict["gaia_given_name"] as? String
            let gaiaName = profileDict["gaia_name"] as? String
            for titleName in Set([name, gaiaGivenName, gaiaName].compactMap { $0 }.filter { !$0.isEmpty }) {
                result[titleName] = icon
            }
        }

        return result
    }
}
