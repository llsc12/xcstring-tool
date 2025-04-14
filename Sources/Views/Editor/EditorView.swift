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

	@State var selectedKey: String? = nil

	@State var selectedLocalizationForDeletion: String? = nil

	@State var isAddingNewLanguage: Bool = false

	var body: some View {
		HStack {
			sidebar
				.frame(width: 25)

			if self.showingMenu {
				menu
			} else {
				editor
			}
		}
	}

	@ViewBuilder var sidebar: some View {
		VStack {
			VStack {
				Text("\(file.strings.count) Localizations")
				Text("Base: \(file.sourceLanguage)")
			}
			.frame(maxWidth: .infinity)
			.border(style: .rounded)

			VStack {
				VStack {
					if selectedLocalizationForDeletion != nil {
						sidebarRemoveLanguage
					} else if isAddingNewLanguage {
						sidebarAddLanguage
					} else {
						sidebarDefault
					}
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)

				Divider()
				HStack {
					Button(" + ") {
						guard
							isAddingNewLanguage == false
								&& selectedLocalizationForDeletion == nil
						else { return }
					}
					.bold()

					if selectedLanguage != file.sourceLanguage {
						Button(" - ") {
							guard
								isAddingNewLanguage == false
									&& selectedLocalizationForDeletion == nil
							else { return }
							self.selectedLocalizationForDeletion = selectedLanguage
						}
						.bold()
					} else {
						Text(" - ")
							.bold()
							.foregroundColor(.gray)
					}

					Spacer()

					Text(
						"\(Set(file.strings.values.compactMap(\.localizations).flatMap(\.keys).map { $0 as String }).count) Languages"
					)
					.foregroundColor(.gray)
				}
				.padding(.horizontal)
			}
			.border(style: .rounded)
		}
	}

	@ViewBuilder var sidebarDefault: some View {
		ScrollView {
			VStack(alignment: .center) {
				Button(" Menu ") {
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
					Button(" \(language) ") {
						self.selectedKey = nil
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
	}

	@ViewBuilder var sidebarAddLanguage: some View {
		Text("add")
	}

	@ViewBuilder var sidebarRemoveLanguage: some View {
		VStack(alignment: .center) {
			Text("Delete \(selectedLocalizationForDeletion ?? "")?")

			VStack(alignment: .center) {

				Button(" Delete ") {
					fatalError("unimplemented")
				}
				.foregroundColor(.red)

				Divider()

				Button(" Cancel ") {
					self.selectedLocalizationForDeletion = nil
				}
			}
			.border(.rounded)
			.padding()
		}
	}

	@ViewBuilder var menu: some View {
		VStack(alignment: .center) {
			Text(editorViewModel.file?.path ?? "")
				.padding(.bottom)
			VStack(alignment: .center) {
				Button(" Save and exit ") {
					self.editorViewModel.reset(save: true)
				}
				.bold()
				.padding()

				Divider()

				Button(" Exit without saving ") {
					self.editorViewModel.reset(save: false)
				}
				.padding()
				.foregroundColor(.red)
			}
			.border(style: .rounded)
			.padding(.horizontal)

			Button(" Back ") {
				self.showingMenu.toggle()
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.border(style: .rounded)
	}

	@ViewBuilder var editor: some View {
		GeometryReader { size in
			VStack {
				Group {
					if selectedKey != nil {
						localisationEditor(size)
					} else {
						localisationsList(size)
					}
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				Divider()
				HStack {
					Text("\(file.strings.count) Localizations")
					Spacer()
					if selectedLanguage != file.sourceLanguage {
						let percentage: Int = {
							// calculate percentage of completed translations for the selected language
							let total = file.strings.count
							let translated = file.strings.filter {
								$0.value.localizations?[selectedLanguage]?.getState(
									isBaseLanguage: selectedLanguage == self.file.sourceLanguage
								) == .translated || $0.value.shouldTranslate == false
							}.count
							let percentage = (translated * 100) / total
							return percentage
						}()
						Text("\(percentage)% translated")
							.foregroundColor(percentage == 100 ? .green : .default)
							.bold()
					}
				}
				.padding(.horizontal, 1)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.border(style: .rounded)
		}
	}

	@ViewBuilder
	func localisationEditor(_ size: Size) -> some View {
		LocalizationEditor(
			editorViewModel: editorViewModel,
			selectedKey: $selectedKey,
			localization: self.file.strings[selectedKey!]!,
			selectedLanguage: self.selectedLanguage
		)
	}

	func localisationsList(_ size: Size) -> some View {
		ScrollView {
			HStack {
				VStack {
					ForEach(file.strings.sorted(by: { $0.key < $1.key }), id: \.key) {
						key,
						stringSet in

						if stringSet.shouldTranslate == false {
							Text("Don't translate")
								.foregroundColor(.red)
								.bold()
						} else {
							let localisation = stringSet.localizations?[selectedLanguage]
							switch localisation?.getState(
								isBaseLanguage: selectedLanguage == self.file.sourceLanguage
							) {
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
				}
				.frame(width: 15)
				.padding(.horizontal, 1)
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
							self.selectedKey = key
						}
						.foregroundColor(text.isEmpty ? .gray : .default)
					}
				}
			}
		}
	}
}

struct LocalizationEditor: View {
	var editorViewModel: EditorViewModel
	@Binding var selectedKey: String?
	var localization: StringSet
	var selectedLanguage: String

	var body: some View {
		VStack(alignment: .center) {
			VStack {
				HStack {
					Button(" Cancel ") {
						self.selectedKey = nil
					}

					Button(" Save ") {

					}
					.bold()

					Divider()

					Text("Editing Localization")
				}

				Divider()
			}
			.frame(height: 2)

			VStack {
				TextField(placeholder: "Localization goes here", initialValue: "meow") {
					_ in

				} update: { _ in

				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
	}
}
