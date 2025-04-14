//
//  ContentView.swift
//  xcstring-tool
//
//  Created by Lakhan Lothiyi on 14/04/2025.
//

import Foundation
import SwiftTUI

struct ContentView: View {
	var editorViewModel: EditorViewModel = .init()
	@State var fileDidntExist: Bool = false
	@State var invalidFile: Bool = false

	@State var searchTask: Task<Void, Never>? = nil
	@State var relevantPaths: [URL] = []
	@State var partial: String?

	var body: some View {
		if editorViewModel.localizationFile != nil {
			EditorView(editorViewModel: editorViewModel)
		} else {
			startupMenu
		}
	}

	@State var repoButton: Bool = false

	var startupMenu: some View {
		HStack {
			VStack {
				VStack {
					Text("xcstring-tool")
						.bold()
					Text("Edit xcstrings files")
					Text("anywhere!")

					Spacer()

					if repoButton {
						Button("llsc12/xcstring-tool") {
							let url = "\"https://github.com/llsc12/xcstring-tool\""
							#if os(macOS)
								_ = try? Shell.run("open", url)
							#elseif os(Linux)
								_ = try? Shell.run("xdg-open", url)
							#endif
						}
					}

					Text("v\(_version)")
						.bold()
						.onAppear {
							DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
								repoButton = true
							}
						}
				}
				.frame(maxWidth: .infinity)
				.border(style: .rounded)
			}
			.frame(width: 25)

			VStack {
				HStack {
					Group {
						if fileDidntExist {
							Text("No such file")
								.foregroundColor(.red)
						} else if invalidFile {
							Text("Invalid file")
								.foregroundColor(.red)
						} else {
							Text("File Search ")
						}
					}
					.bold()
					.padding(.left, 1)

					Divider()

					TextField(
						placeholder: "Search Files",
						initialValue: partial ?? "",
						action: textfieldSubmit(_:),
						update: textfieldUpdate(_:)
					)
					.environment(\.placeholderColor, .gray)

					Spacer()
				}
				.frame(maxHeight: 1)

				Divider()

				filebox
					.padding(.left, 1)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.border(style: .rounded)
		}
	}

	@ViewBuilder var filebox: some View {
		if relevantPaths.isEmpty {
			ScrollView {
				Text("Recent Files")
					.underline()
					.padding(.bottom, 1)

				if editorViewModel.fileHistory.isEmpty {
					Text("Recently opened files will appear here!")
						.foregroundColor(.gray)
				} else {
					ForEach(editorViewModel.fileHistory, id: \.self) { url in
						Button("\(url.absoluteURL.path)") {
							self.textfieldSubmit(url.absoluteURL.path)
						}
					}
				}
			}
		} else {
			ScrollView {
				ForEach(relevantPaths, id: \.self) { url in
					Button("./\(url.lastPathComponent)") {
						self.textfieldSubmit(url.absoluteURL.path)
					}
				}
			}
		}
	}

	func textfieldSubmit(_ path: String) {
		let url = URL(fileURLWithPath: path)
		if !FileManager.default.fileExists(atPath: url.path) {
			self.fileDidntExist = true
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				self.fileDidntExist = false
			}
			return
		}
		if !url.pathExtension.hasSuffix("xcstrings") {
			self.invalidFile = true
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				self.invalidFile = false
			}
			return
		}
		self.partial = path
		self.editorViewModel.file = url
	}

	func textfieldUpdate(_ partialPath: String) {
		if partialPath.isEmpty {
			self.relevantPaths = []
			self.partial = nil
			return
		}
		let url = URL(
			fileURLWithPath: partialPath.replacingOccurrences(
				of: "~",
				with: NSHomeDirectory()
			)
		)
		var partial = url
		if !FileManager.default.fileExists(atPath: url.absoluteURL.path) {
			partial = url.deletingLastPathComponent()
			self.partial = partialPath
		}
		if !url.hasDirectoryPath {
			partial = url.deletingLastPathComponent()
			self.partial = partialPath
		}

		let paths = try? FileManager.default
			.contentsOfDirectory(
				at: partial.absoluteURL,
				includingPropertiesForKeys: nil,
				options: [.skipsHiddenFiles]
			)
			.filter {
				$0.lastPathComponent.hasSuffix(".xcstrings") || $0.hasDirectoryPath
			}
			.sorted { $0.hasDirectoryPath || $0.path < $1.path }

		self.relevantPaths = paths ?? []
	}
}
