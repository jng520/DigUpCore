import Foundation

/// A problem with one input (it gets no vector; its neighbours go on).
struct LlamaError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

