@testable import DockDoor
import Testing

struct QuitAppOnLastWindowClosePolicyTests {
    private let safari = "com.apple.Safari"
    private let outlook = "com.microsoft.Outlook"

    @Test func allAppsExceptSelectedQuitsUnlistedApp() {
        let result = WindowUtil.shouldQuitAppOnLastWindowClose(
            bundleIdentifier: safari,
            mode: .allAppsExceptSelected,
            excludedApps: [outlook],
            allowedApps: []
        )

        #expect(result)
    }

    @Test func allAppsExceptSelectedKeepsExcludedAppRunning() {
        let result = WindowUtil.shouldQuitAppOnLastWindowClose(
            bundleIdentifier: outlook,
            mode: .allAppsExceptSelected,
            excludedApps: [outlook],
            allowedApps: []
        )

        #expect(!result)
    }

    @Test func selectedAppsOnlyQuitsAllowedApp() {
        let result = WindowUtil.shouldQuitAppOnLastWindowClose(
            bundleIdentifier: safari,
            mode: .selectedAppsOnly,
            excludedApps: [],
            allowedApps: [safari]
        )

        #expect(result)
    }

    @Test func selectedAppsOnlyKeepsUnlistedAppRunning() {
        let result = WindowUtil.shouldQuitAppOnLastWindowClose(
            bundleIdentifier: outlook,
            mode: .selectedAppsOnly,
            excludedApps: [],
            allowedApps: [safari]
        )

        #expect(!result)
    }

    @Test(arguments: QuitAppOnWindowCloseMode.allCases)
    func finderAlwaysStaysRunning(mode: QuitAppOnWindowCloseMode) {
        let result = WindowUtil.shouldQuitAppOnLastWindowClose(
            bundleIdentifier: "com.apple.finder",
            mode: mode,
            excludedApps: [],
            allowedApps: ["com.apple.finder"]
        )

        #expect(!result)
    }

    @Test func unidentifiedAppPreservesAllAppsBehavior() {
        let result = WindowUtil.shouldQuitAppOnLastWindowClose(
            bundleIdentifier: nil,
            mode: .allAppsExceptSelected,
            excludedApps: [],
            allowedApps: []
        )

        #expect(result)
    }

    @Test func unidentifiedAppDoesNotMatchSelectedAppsOnly() {
        let result = WindowUtil.shouldQuitAppOnLastWindowClose(
            bundleIdentifier: nil,
            mode: .selectedAppsOnly,
            excludedApps: [],
            allowedApps: []
        )

        #expect(!result)
    }
}
