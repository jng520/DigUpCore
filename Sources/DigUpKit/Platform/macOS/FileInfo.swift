import Foundation

/// Facts about a filesystem entry used by the macOS crawler.
struct FileInfo {
    let isRegular: Bool
    let size: Int64
    let mtime: Double
    let inode: UInt64
    let device: UInt64
    let dataless: Bool
}
