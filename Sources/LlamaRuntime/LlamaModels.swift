import DigUpKit
import Foundation

/// Where the EmbeddingGemma 2 files for llama.cpp are (see `ModelFiles` for which files, and why Q8_0).
public struct LlamaModels: Sendable {
    public static let repository = ModelFiles.repository
    public static let revision = ModelFiles.revision
    /// The text part (310 MB): all that queries need.
    public static let textFile = ModelFiles.text.name
    /// The image and audio encoders (555 MB).
    public static let mediaFile = ModelFiles.media.name

    public let text: URL
    /// Nil while only the text part is there.
    public let media: URL?

    /// The folders to look in, first match wins. `$DIGUP_MODELS` is the app's choice and the only place it looks
    /// then: it will not fall back to any other directory. Without it, use Application Support.
    /// No automatic download or remote cache discovery.
    public static var folders: [URL] {
        if let chosen = ProcessInfo.processInfo.environment["DIGUP_MODELS"], !chosen.isEmpty {
            return [URL(fileURLWithPath: chosen)]
        }
        return [ModelFiles.installed]
    }

    /// The first folder with the text part. Missing files are a `WorkerError`, so an indexing run stops and its files
    /// stay pending.
    public static func locate() throws -> LlamaModels {
        for folder in folders {
            let text = folder.appendingPathComponent(textFile)
            guard FileManager.default.fileExists(atPath: text.path) else { continue }
            let media = folder.appendingPathComponent(mediaFile)
            return LlamaModels(text: text, media: FileManager.default.fileExists(atPath: media.path) ? media : nil)
        }
        throw WorkerError.notFound("no \(textFile) in " + folders.map(\.path).joined(separator: ", ")
            + "; select the matching GGUF files in DigUp")
    }

    /// Both files are there, so indexing can run (checked without loading anything).
    public static var complete: Bool {
        (try? locate())?.media != nil
    }
}
