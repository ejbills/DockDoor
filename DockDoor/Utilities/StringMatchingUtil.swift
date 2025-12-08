import Foundation

enum StringMatchingUtil {
    /// Performs fuzzy matching based on fuzziness level (1-5).
    /// Level 1: Exact substring match (strictest)
    /// Level 2: Characters in order, max 1 char gap between matches
    /// Level 3: Characters in order, max 3 char gap between matches
    /// Level 4: Characters in order, max 5 char gap between matches
    /// Level 5: Characters in order, no gap limit (most lenient)
    static func fuzzyMatch(query: String, target: String, fuzziness: Int) -> Bool {
        if query.isEmpty { return true }
        if target.isEmpty { return false }

        // Level 1: exact substring match
        if fuzziness == 1 {
            return target.contains(query)
        }

        // Levels 2-5: fuzzy matching with varying gap tolerances
        let maxGap: Int? = switch fuzziness {
        case 2: 1
        case 3: 3
        case 4: 5
        default: nil // Level 5: no limit
        }

        let queryCount = query.count
        let targetCount = target.count

        // Early termination: if target is shorter than query, can't match
        if targetCount < queryCount {
            return false
        }

        // Try matching starting from each position in target
        var searchStart = target.startIndex
        let maxStartPosition = target.index(target.endIndex, offsetBy: -(queryCount - 1), limitedBy: target.startIndex) ?? target.startIndex

        outer: while searchStart <= maxStartPosition {
            var queryIndex = query.startIndex
            var targetIndex = searchStart
            var lastMatchIndex: String.Index?
            var remainingQuery = queryCount

            // Early termination: check if enough characters remain in target
            let remainingTarget = target.distance(from: targetIndex, to: target.endIndex)
            if remainingTarget < remainingQuery {
                break
            }

            while queryIndex < query.endIndex {
                // Early termination: not enough characters left in target
                let charsLeft = target.distance(from: targetIndex, to: target.endIndex)
                if charsLeft < remainingQuery {
                    searchStart = target.index(after: searchStart)
                    continue outer
                }

                guard targetIndex < target.endIndex else {
                    searchStart = target.index(after: searchStart)
                    continue outer
                }

                if query[queryIndex] == target[targetIndex] {
                    // Check gap constraint if applicable
                    if let maxGapValue = maxGap, let lastMatch = lastMatchIndex {
                        let gap = target.distance(from: lastMatch, to: targetIndex) - 1
                        if gap > maxGapValue {
                            // Gap too large, try next starting position
                            searchStart = target.index(after: searchStart)
                            continue outer
                        }
                    }
                    lastMatchIndex = targetIndex
                    queryIndex = query.index(after: queryIndex)
                    remainingQuery -= 1
                }
                targetIndex = target.index(after: targetIndex)
            }

            if queryIndex == query.endIndex {
                return true
            }
            searchStart = target.index(after: searchStart)
        }

        return false
    }
}
