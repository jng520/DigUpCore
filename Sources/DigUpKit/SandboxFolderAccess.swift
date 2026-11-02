import Foundation

/// Persists only user-selected security-scoped URLs. The app and its inherited-sandbox
/// helper restore these bookmarks before accessing files outside the app container.
/// Bookmarks are kept in the app container, not in GGUFModelLoader.
public enum SandboxFolderAccess {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var opened: [String: URL] = [:]

    private static var bookmarksFile: URL {
        AppPaths.applicationSupport.appendingPathComponent("SelectedFiles.plist")
    }

    private static func loadBookmarks() -> [String: Data] {
        guard let data = try? Data(contentsOf: bookmarksFile),
              let list = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Data] else { return [:] }
        return list
    }

    /// Called with the original URL returned by NSOpenPanel, while its grant is valid.
    @discardableResult
    public static func remember(_ url: URL, activate: Bool = true) -> Bool {
        let path = url.standardizedFileURL.path
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope],
                                            includingResourceValuesForKeys: nil, relativeTo: nil)
            lock.lock()
            defer { lock.unlock() }
            var saved = loadBookmarks()
            saved[path] = data
            try FileManager.default.createDirectory(at: AppPaths.applicationSupport,
                                                     withIntermediateDirectories: true)
            let plist = try PropertyListSerialization.data(fromPropertyList: saved,
                                                            format: .binary, options: 0)
            try plist.write(to: bookmarksFile, options: .atomic)
            if activate, opened[path] == nil {
                var stale = false
                let resolved = try URL(resolvingBookmarkData: data, options: [.withSecurityScope],
                                       relativeTo: nil, bookmarkDataIsStale: &stale)
                // NSOpenPanel URLs already carry access; a false return can mean
                // the scope was implicitly started by the system open panel.
                _ = resolved.startAccessingSecurityScopedResource()
                opened[path] = resolved
            }
            return true
        } catch {
            NSLog("DigUp: cannot retain access to %@: %@", path, error.localizedDescription)
            return false
        }
    }

    /// Restores persisted grants on app startup and in each helper invocation.
    @discardableResult
    public static func restore() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        var urls: [URL] = []
        for (path, data) in loadBookmarks() {
            if let already = opened[path] { urls.append(already); continue }
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope],
                                  relativeTo: nil, bookmarkDataIsStale: &stale)
                if url.startAccessingSecurityScopedResource() {
                    opened[path] = url
                    urls.append(url)
                } else {
                    NSLog("DigUp: security scope unavailable for %@; choose the folder again", path)
                }
            } catch {
                NSLog("DigUp: bookmark no longer valid for %@: %@", path, error.localizedDescription)
            }
        }
        return urls
    }

    /// Resolve a saved model-history URL without retaining long-lived access; ModelStore opens
    /// its own security scope for the duration of the import.
    public static func resolved(_ path: String) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = loadBookmarks()[path] else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: [.withSecurityScope],
                        relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    /// Only a granted folder or its descendants can be passed to the indexing helper.
    public static func authorized(_ url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let path = url.standardizedFileURL.path
        return opened.keys.contains { path == $0 || path.hasPrefix($0 + "/") }
    }
    /// Export *transient* implicit-scope bookmarks for an inherited-sandbox child.
    /// The child cannot use the app-scoped persisted bookmarks with only its two
    /// required inherit entitlements. This file lives inside the shared app container.
    private static var helperBookmarksFile: URL {
        AppPaths.applicationSupport.appendingPathComponent("HelperGrants.plist")
    }

    public static func prepareHelpers() {
        lock.lock()
        defer { lock.unlock() }
        do {
            let grants = try opened.mapValues {
                try $0.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            }
            try FileManager.default.createDirectory(at: AppPaths.applicationSupport,
                                                     withIntermediateDirectories: true)
            let plist = try PropertyListSerialization.data(fromPropertyList: grants,
                                                            format: .binary, options: 0)
            try plist.write(to: helperBookmarksFile, options: .atomic)
        } catch {
            NSLog("DigUp: cannot share selected folder access with helper: %@", error.localizedDescription)
        }
    }

    /// Called only in the signed inherited-sandbox digup child process.
    public static func restoreForHelper() {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: helperBookmarksFile),
              let grants = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Data] else { return }
        for (path, bookmark) in grants where opened[path] == nil {
            do {
                var stale = false
                // Implicit-scoped bookmarks passed between processes use [] on resolution.
                let url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil,
                                  bookmarkDataIsStale: &stale)
                _ = url.startAccessingSecurityScopedResource()
                opened[path] = url
            } catch {
                NSLog("DigUp helper: no access to %@: %@", path, error.localizedDescription)
            }
        }
    }

    public static func forget(_ path: String) {
        lock.lock()
        defer { lock.unlock() }
        var saved = loadBookmarks()
        guard saved.removeValue(forKey: path) != nil else { return }
        do {
            let plist = try PropertyListSerialization.data(fromPropertyList: saved,
                                                            format: .binary, options: 0)
            try plist.write(to: bookmarksFile, options: .atomic)
            if let url = opened.removeValue(forKey: path) {
                url.stopAccessingSecurityScopedResource()
            }
        } catch {
            NSLog("DigUp: cannot clear saved access to %@: %@", path, error.localizedDescription)
        }
    }

}
