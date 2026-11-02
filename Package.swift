// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DigUpCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DigUpKit", targets: ["DigUpKit"]),
        .executable(name: "digup", targets: ["digup"])
    ],
    dependencies: [.package(path: "../GGUFModelLoader")],
    targets: [
        .target(name: "DigUpKit"),
        .target(name: "LlamaRuntime", dependencies: ["DigUpKit", .product(name: "CLlama", package: "GGUFModelLoader"),
                .product(name: "GGUFModelLoader", package: "GGUFModelLoader")],
                linkerSettings: [.unsafeFlags(["-L\(Context.packageDirectory)/../GGUFModelLoader/Vendor/llama/lib"])]),
        .executableTarget(name: "digup", dependencies: ["DigUpKit", "LlamaRuntime"])
    ]
)
