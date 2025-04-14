// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "xcstring-tool",
	platforms: [
		.macOS(.v14)
	],
	products: [
		.executable(name: "xcstring-tool", targets: [
			"xcstring-tool"
		])
	],
	dependencies: [
		.package(url: "https://github.com/llsc12/SwiftTUI", branch: "main"),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.executableTarget(
			name: "xcstring-tool",
			dependencies: [
				.product(name: "SwiftTUI", package: "SwiftTUI"),
			],
		)
	]
)
