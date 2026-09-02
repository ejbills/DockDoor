import CoreGraphics
import Foundation

/// Detects native macOS window-tab groups and selects one representative window per group.
///
/// macOS native window tabbing (`NSWindow` tabbing, used by Ghostty, Finder, Terminal,
/// Safari, and others) models each tab as a distinct window. The Accessibility API reports
/// each of those windows separately, which is why a single tabbed window otherwise shows up
/// as one preview per tab.
///
/// There is no Accessibility attribute that exposes tab-group membership for arbitrary apps,
/// so membership is inferred from a reliable side effect: the windows in one visible tab group
/// are stacked at the exact same screen frame, and only the selected tab is on screen. Windows
/// that share a process and an (integer-rounded) frame are therefore treated as a single group,
/// except that on-screen members are always distinct windows and are all kept.
enum NativeTabGrouping {
    /// The minimal window facts needed to detect tab groups, kept free of Accessibility and
    /// AppKit types so the grouping logic stays pure and unit-testable.
    struct Candidate {
        let id: CGWindowID
        let pid: pid_t
        let frame: CGRect
        /// Used to pick which member represents its group; the most recently accessed window
        /// (typically the active tab) wins.
        let recency: Date
        /// Whether this window may be collapsed into a group. Minimized, hidden, windowless,
        /// and zero-sized windows are never collapsed and are always kept as-is.
        let groupable: Bool
        let isOnScreen: Bool
    }

    private struct GroupKey: Hashable {
        let pid: pid_t
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    /// Returns the window IDs to keep: every non-groupable window, every on-screen window, plus a
    /// single representative for each group with no on-screen member.
    ///
    /// The representative is the most recently accessed window in the group; ties are broken by
    /// the larger window ID so the result is deterministic regardless of input ordering.
    static func representativeIDs(from candidates: [Candidate]) -> Set<CGWindowID> {
        var keptIDs = Set<CGWindowID>()
        var representativeByGroup: [GroupKey: Candidate] = [:]
        var groupsWithOnScreenMember = Set<GroupKey>()

        for candidate in candidates {
            guard candidate.groupable else {
                keptIDs.insert(candidate.id)
                continue
            }

            let key = GroupKey(
                pid: candidate.pid,
                x: Int(candidate.frame.origin.x.rounded()),
                y: Int(candidate.frame.origin.y.rounded()),
                width: Int(candidate.frame.size.width.rounded()),
                height: Int(candidate.frame.size.height.rounded())
            )

            if candidate.isOnScreen {
                keptIDs.insert(candidate.id)
                groupsWithOnScreenMember.insert(key)
                continue
            }

            if let current = representativeByGroup[key] {
                if isBetterRepresentative(candidate, than: current) {
                    representativeByGroup[key] = candidate
                }
            } else {
                representativeByGroup[key] = candidate
            }
        }

        for (key, representative) in representativeByGroup where !groupsWithOnScreenMember.contains(key) {
            keptIDs.insert(representative.id)
        }

        return keptIDs
    }

    private static func isBetterRepresentative(_ candidate: Candidate, than current: Candidate) -> Bool {
        // Most recently accessed wins; the larger window ID breaks ties so the result is
        // deterministic regardless of input ordering.
        (candidate.recency, candidate.id) > (current.recency, current.id)
    }
}
