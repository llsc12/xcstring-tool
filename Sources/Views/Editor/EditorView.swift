//
//  EditorView.swift
//  xcstring-tool
//
//  Created by Lakhan Lothiyi on 14/04/2025.
//

import Foundation
import SwiftTUI

struct EditorView: View {
	var editorViewModel: EditorViewModel

	@State var showingMenu = false

	@State var selectedLanguage: String

	let file: LocalizationFile

	init(editorViewModel: EditorViewModel) {
		self.editorViewModel = editorViewModel
		self._selectedLanguage = .init(
			initialValue: editorViewModel.localizationFile!.sourceLanguage
		)
		self.file = editorViewModel.localizationFile!
	}

	var body: some View {
		HStack {
			VStack {
				VStack {
					Text("\(file.strings.count) Localizations")
					Text("Base: \(file.sourceLanguage)")
				}
				.frame(maxWidth: .infinity)
				.border(style: .rounded)

				ScrollView {
					VStack(alignment: .center) {
						Button("Menu") {
							showingMenu.toggle()
						}
						.bold(showingMenu)

						Divider()

						ForEach(
							Array(
								Set(
									file.strings.values.compactMap(\.localizations).flatMap(
										\.keys
									)
									.map { $0 as String }
								)
							)
							.sorted { lhs, rhs in
								if lhs == file.sourceLanguage { return true }
								if rhs == file.sourceLanguage { return false }
								return lhs < rhs
							},

							id: \.self
						) { language in
							Button(language) {
								self.selectedLanguage = language
							}
							.padding()
							.frame(maxWidth: .infinity)
							.background(selectedLanguage == language ? Color.gray : .default)
						}
					}
					.frame(width: 25)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.border(style: .rounded)
			}
			.frame(width: 25)

			if self.showingMenu {
				menu
			} else {
				editor
			}
		}
	}

	@ViewBuilder var menu: some View {
		VStack(alignment: .center) {
			Text(editorViewModel.file?.path ?? "")
				.padding(.bottom)
			VStack(alignment: .center) {
				Button("Save and exit") {
					self.editorViewModel.reset(save: true)
				}
				.bold()
				.padding()

				Divider()

				Button("Exit without saving") {
					self.editorViewModel.reset(save: false)
				}
				.padding()
				.foregroundColor(.red)
			}
			.border(style: .rounded)
			.padding(.horizontal)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.border(style: .rounded)
	}

	@ViewBuilder var editor: some View {
		GeometryReader { size in
			ScrollView {
				HStack {
					VStack {
						ForEach(file.strings.sorted(by: { $0.key < $1.key }), id: \.key) {
							key,
							stringSet in

							let localisation = stringSet.localizations?[selectedLanguage]
							switch localisation?.state {
							case .notTranslated:
								Text("Untranslated")
									.foregroundColor(.red)
									.bold()
							case .needsReview:
								Text("Needs review")
									.foregroundColor(.yellow)
							case .stale:
								Text("Stale")
									.foregroundColor(.yellow)
							case .new:
								Text("New")
									.foregroundColor(.blue)
									.bold()
							case .translated:
								Text("Translated")
									.foregroundColor(.green)
							default:
								Text(" ")
							}
						}
					}
					.frame(width: 15)
					.padding(.left, 1)
					Divider()
					VStack {
						ForEach(file.strings.sorted(by: { $0.key < $1.key }), id: \.key) {
							key,
							stringSet in

							let text: (isEmpty: Bool, str: String) = {
								let prefixAdditive = 18
								// be sure to re-escape \n and \t
								let key: (Bool, String) = {
									if key.isEmpty { return (true, "(Empty string)") }
									return (
										false,
										key
											.replacingOccurrences(of: "\n", with: "\\n")
											.replacingOccurrences(of: "\t", with: "\\t")
									)
								}()

								let size = size.width.intValue - prefixAdditive
								if key.1.count > size {
									// ensure prefix is never less than 3 characters
									let prefix = max(0, size)
									return (key.0, key.1.prefix(prefix) + "...")
								} else {
									return key
								}
							}()

							Button(text.str) {
								// ...
							}
							.foregroundColor(text.isEmpty ? .gray : .default)
						}
					}
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.border(style: .rounded)
		}
	}
}
