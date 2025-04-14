//
//  EditorViewModel.swift
//  xcstring-tool
//
//  Created by Lakhan Lothiyi on 14/04/2025.
//

import Foundation
import Observation
import SwiftTUI

@Observable
class EditorViewModel {
	let decoder = JSONDecoder()
	let encoder = JSONEncoder()

	var file: URL? {
		didSet {
			if let file {
				loadFile(file)
			} else {
				reset()
			}
		}
	}

	var localizationFile: LocalizationFile?

	// MARK: - File open history

	static let fileHistoryDocURL: URL = .homeDirectory.appendingPathComponent(
		".xcstring-tool-file-history"
	)

	var fileHistory: [URL] {
		get {
			do {
				let data = try Data(contentsOf: Self.fileHistoryDocURL)
				let decoded = try decoder.decode([URL].self, from: data)
				return decoded
			} catch {
				log("Error loading file history: \(error)")
				return []
			}
		}
		set {
			do {
				let data = try encoder.encode(newValue)
				try data.write(to: Self.fileHistoryDocURL)
			} catch {
				log("Error saving file history: \(error)")
			}
		}
	}

	func addFileToHistory(_ file: URL) {
		let history = fileHistory
		let newHistory =
			[file]
			+ history.filter {
				$0.path.lowercased() != file.path.lowercased()
			}  // add file to front of list
		fileHistory = newHistory
	}

	// MARK: - Setup and Teardown

	func loadFile(_ file: URL) {
		do {
			let data = try Data(contentsOf: file)
			let decoded = try decoder.decode(LocalizationFile.self, from: data)

			self.localizationFile = decoded
			self.addFileToHistory(file)
		} catch {
			log("Error loading file: \(error)")
		}
	}

	func reset(save: Bool = false) {
		// save file then reset view model
		do {
			if let file, save, let localizationFile {
				let data = try encoder.encode(localizationFile)
				try data.write(to: file)
			}
		} catch {
			log("Error saving file: \(error)")
		}
		self.localizationFile = nil
	}
}

// MARK: - JSON structures

struct LocalizationFile: Codable {
	let sourceLanguage: String
	var strings: [String: StringSet]
	let version: String
}

struct StringSet: Codable {
	var comment: String?
	var localizations: [String: Localization]?
	var shouldTranslate: Bool?
}

struct Localization: Codable {
	var stringUnit: StringUnit?
	var variations: Variations?

	enum CodingKeys: String, CodingKey {
		case stringUnit, variations
	}
}

struct StringUnit: Codable {
	var state: StringUnitState
	var value: String
}

enum StringUnitState: String, Codable {
	case new
	case translated
	case needsReview = "needs_review"
	case stale
	
	case notTranslated // custom, used only in this app
}

struct Variations: Codable {
	var plural: [String: Variation]?
	var device: [String: Variation]?

	enum CodingKeys: String, CodingKey {
		case plural, device
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		plural = try container.decodeIfPresent(
			[String: Variation].self,
			forKey: .plural
		)
		device = try container.decodeIfPresent(
			[String: Variation].self,
			forKey: .device
		)
	}
}

struct Variation: Codable {
	var stringUnit: StringUnit
}


extension Localization {
	var state: StringUnitState {
		let allstringunits = {
			var stringunits: [StringUnit] = []
			if let a = stringUnit {
				stringunits.append(a)
			}
			stringunits.append(contentsOf: variations?.plural?.values.map(\.stringUnit) ?? [])
			stringunits.append(contentsOf: variations?.device?.values.map(\.stringUnit) ?? [])
			return stringunits
		}()
		
		if allstringunits.isEmpty {
			return .notTranslated
		} else {
			// get the first state
			let firstState = allstringunits[0].state
			return firstState
		}
	}
}
