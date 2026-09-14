// swift-tools-version: 5.9
import PackageDescription

/// SalvageCore — biblioteca de regras puras do jogo.
///
/// Este package é consumido pelo app iOS SalvageApp (projeto Xcode
/// separado, na pasta irmã). Zero dependências de UI aqui — só
/// structs, enums e a função pura GameEngine.apply(action, state).
let package = Package(
    name: "SalvageCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SalvageCore", targets: ["SalvageCore"]),
    ],
    targets: [
        .target(
            name: "SalvageCore",
            path: "Sources/SalvageCore"
        ),
        .testTarget(
            name: "SalvageCoreTests",
            dependencies: ["SalvageCore"],
            path: "Tests/SalvageCoreTests"
        ),
    ]
)
