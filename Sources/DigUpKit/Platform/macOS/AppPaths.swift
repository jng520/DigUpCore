import Foundation

/// Application storage locations on macOS.
public enum AppPaths {
    public static var applicationSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DigUp", isDirectory: true)
    }

    public static var defaultIndex: URL {
        applicationSupport.appendingPathComponent("index.noindex")
    }
}
