import Foundation

extension Data {
    /// Replace atomically, so readers never observe a half-written file.
    public func writeReplacing(_ url: URL) throws {
        try write(to: url, options: .atomic)
    }
}
