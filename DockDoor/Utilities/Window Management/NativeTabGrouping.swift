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
/// are stacked at the exact same screen frame. Windows that share a process and an
/// (integer-rounded) frame are therefore treated as a single group, and callers can keep just
/// the representative to collapse a tabbed app down to one entry.
enum NativeTabGrouping {
    /// The minimal window facts needed to detect tab groups, kept free of Accessibility and
    /// AppKit types so the grouping logic stays pure and unit-testable.
    struct Candidate {
        let id: CGWindowID
        let pid: pid_t
        let frame: CGRect
        /// Used to pick which member represents its group when none is focused.
        let recency: Date
        /// Whether the application currently reports this member through
        /// `kAXFocusedWindowAttribute`.
        let isFocused: Bool
        /// Whether this window may be collapsed into a group. Minimized, hidden, windowless,
        /// and zero-sized windows are never collapsed and are always kept as-is.
        let groupable: Bool
    }

    struct Group: Equatable {
        let representativeID: CGWindowID
        let memberIDs: Set<CGWindowID>
    }

    private struct GroupKey: Hashable {
        let pid: pid_t
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    /// Returns every detected group with its selected representative and complete membership.
    static func groups(from candidates: [Candidate]) -> [Group] {
        var standaloneGroups: [Group] = []
        var membersByGroup: [GroupKey: [Candidate]] = [:]

        for candidate in candidates {
            guard candidate.groupable else {
                standaloneGroups.append(Group(representativeID: candidate.id, memberIDs: [candidate.id]))
                continue
            }

            let key = GroupKey(
                pid: candidate.pid,
                x: Int(candidate.frame.origin.x.rounded()),
                y: Int(candidate.frame.origin.y.rounded()),
                width: Int(candidate.frame.size.width.rounded()),
                height: Int(candidate.frame.size.height.rounded())
            )

            membersByGroup[key, default: []].append(candidate)
        }

        let collapsedGroups = membersByGroup.values.map { members in
            let representative = members.dropFirst().reduce(members[0]) { current, candidate in
                isBetterRepresentative(candidate, than: current) ? candidate : current
            }
            return Group(
                representativeID: representative.id,
                memberIDs: Set(members.map(\.id))
            )
        }

        return (standaloneGroups + collapsedGroups).sorted {
            $0.representativeID < $1.representativeID
        }
    }

    /// Returns the window IDs to keep: every non-groupable window, plus a single representative
    /// per detected tab group.
    static func representativeIDs(from candidates: [Candidate]) -> Set<CGWindowID> {
        Set(groups(from: candidates).map(\.representativeID))
    }

    static func activationWindowID(
        representativeID: CGWindowID,
        memberIDs: Set<CGWindowID>,
        focusedWindowID: CGWindowID?
    ) -> CGWindowID {
        guard let focusedWindowID, memberIDs.contains(focusedWindowID) else {
            return representativeID
        }
        return focusedWindowID
    }

    private static func isBetterRepresentative(_ candidate: Candidate, than current: Candidate) -> Bool {
        if candidate.isFocused != current.isFocused {
            return candidate.isFocused
        }
        return (candidate.recency, candidate.id) > (current.recency, current.id)
    }
}
