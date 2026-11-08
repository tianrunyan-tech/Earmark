import Foundation

extension String {
    /// Removes every match of a regular expression.
    func removingMatches(of pattern: String) -> String {
        replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    /// Capture groups of the first match. Index 0 is the whole match; groups that
    /// did not participate in the match come back as empty strings.
    func captureGroups(matching pattern: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            guard let groupRange = Range(match.range(at: index), in: self) else { return "" }
            return String(self[groupRange])
        }
    }
}
