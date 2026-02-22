// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "MedShelf",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "MedShelf",
            targets: ["AppModule"],
            bundleIdentifier: "com.paola.MedShelf",
            teamIdentifier: "",
            displayVersion: "1.0.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .asset("AccentColor"),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft
            ],
            capabilities: [
                .camera(purposeString: "Camera is used to photograph medicine boxes for inventory")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: ".",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
