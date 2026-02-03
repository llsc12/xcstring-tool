//
//  FileLoadingModel.swift
//  xcstring-tool
//
//  Created by Lakhan Lothiyi on 14/04/2025.
//

import Foundation
import Observation
import SwiftTUI

@Observable
class FileLoadingModel {
  static let shared = FileLoadingModel()
  let decoder = JSONDecoder()
  let encoder = JSONEncoder()

  var newFileLoadedCallback: ((LocalizationFile) -> Void)?

  private init(file: URL? = nil, localizationFile: LocalizationFile? = nil) {
    self.file = file
    self.localizationFile = localizationFile
  }

  var file: URL? {
    didSet {
      if let file {
        guard let file = loadFile(file) else {
          log("Error loading file")
          return
        }
        self.newFileLoadedCallback?(file)
      } else {
        assert(
          localizationFile == nil,
          "Localization file should be nil before file url is set to nil"
        )
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

  @discardableResult
  func loadFile(_ file: URL) -> LocalizationFile? {
    do {
      let data = try Data(contentsOf: file)
      let decoded = try decoder.decode(LocalizationFile.self, from: data)

      self.localizationFile = decoded
      self.addFileToHistory(file)
      return decoded
    } catch {
      log("Error loading file: \(error)")
      return nil
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
    self.file = nil
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

// Update the StringUnitState enum
enum StringUnitState: String, Codable {
  case new
  case translated
  case needsReview = "needs_review"
  case stale
  case notTranslated  // custom, used only in this app
  case none  // For source language entries that don't need translation state
}

struct Variations: Codable {
  var plural: [String: Variation]?
  var device: [String: Variation]?

  init(plural: [String: Variation]? = nil, device: [String: Variation]? = nil) {
    self.plural = plural
    self.device = device
  }

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
  func getState(isBaseLanguage: Bool) -> StringUnitState {
    let allStringUnits = {
      var stringUnits: [StringUnit] = []
      if let unit = stringUnit {
        stringUnits.append(unit)
      }
      stringUnits.append(
        contentsOf: variations?.plural?.values.map(\.stringUnit) ?? []
      )
      stringUnits.append(
        contentsOf: variations?.device?.values.map(\.stringUnit) ?? []
      )
      return stringUnits
    }()

    if allStringUnits.isEmpty {
      if isBaseLanguage {
        return .none
      }
      return .notTranslated
    } else {
      // get the first state
      if allStringUnits[0].state == .translated && isBaseLanguage {
        return .none
      } else {
        return allStringUnits[0].state
      }
    }
  }
}

// MARK: - LocalizationFile Extensions
extension LocalizationFile {
  // Add a new language to the file
  mutating func addLanguage(code: String) {
    for (key, var stringSet) in strings {
      if stringSet.localizations == nil {
        stringSet.localizations = [:]
      }

      // Only add if it doesn't exist
      if stringSet.localizations?[code] == nil {
        stringSet.localizations?[code] = Localization()
      }

      strings[key] = stringSet
    }
  }

  // Remove a language from the file
  mutating func removeLanguage(code: String) {
    guard code != sourceLanguage else {
      // Cannot remove source language
      return
    }

    for (key, var stringSet) in strings {
      stringSet.localizations?[code] = nil
      strings[key] = stringSet
    }
  }

  // Get all language codes in the file
  func getAllLanguages() -> [String] {
    var languages = Set<String>()
    languages.insert(sourceLanguage)

    for (_, stringSet) in strings {
      if let localizations = stringSet.localizations {
        for language in localizations.keys {
          languages.insert(language)
        }
      }
    }

    return Array(languages).sorted()
  }

  // Get all keys with missing translations for a language
  func getMissingTranslations(for languageCode: String) -> [String] {
    var missingKeys: [String] = []

    for (key, stringSet) in strings {
      // Skip keys that shouldn't be translated
      guard stringSet.shouldTranslate != false else { continue }

      if let localization = stringSet.localizations?[languageCode] {
        // Check if this key has any content
        if localization.isEmpty() {
          missingKeys.append(key)
        }
      } else {
        missingKeys.append(key)
      }
    }

    return missingKeys
  }
}

// MARK: - StringSet Extensions
extension StringSet {
  // Add or update a translation for a key
  mutating func setTranslation(
    for languageCode: String,
    value: String,
    state: StringUnitState = .translated
  ) {
    if localizations == nil {
      localizations = [:]
    }

    if localizations?[languageCode] == nil {
      localizations?[languageCode] = Localization()
    }

    if localizations?[languageCode]?.stringUnit == nil {
      localizations?[languageCode]?.stringUnit = StringUnit(
        state: state,
        value: value
      )
    } else {
      localizations?[languageCode]?.stringUnit?.value = value
      localizations?[languageCode]?.stringUnit?.state = state
    }
  }

  // Add or update a plural translation
  mutating func setPluralTranslation(
    for languageCode: String,
    pluralForm: String,  // "one", "other", etc.
    value: String,
    state: StringUnitState = .translated
  ) {
    if localizations == nil {
      localizations = [:]
    }

    if localizations?[languageCode] == nil {
      localizations?[languageCode] = Localization()
    }

    if localizations?[languageCode]?.variations == nil {
      localizations?[languageCode]?.variations = Variations()
    }

    if localizations?[languageCode]?.variations?.plural == nil {
      localizations?[languageCode]?.variations?.plural = [:]
    }

    let variation = Variation(
      stringUnit: StringUnit(state: state, value: value)
    )
    localizations?[languageCode]?.variations?.plural?[pluralForm] = variation
  }

  // Add or update a device-specific translation
  mutating func setDeviceTranslation(
    for languageCode: String,
    deviceType: String,  // "iphone", "ipod", "other", etc.
    value: String,
    state: StringUnitState = .translated
  ) {
    if localizations == nil {
      localizations = [:]
    }

    if localizations?[languageCode] == nil {
      localizations?[languageCode] = Localization()
    }

    if localizations?[languageCode]?.variations == nil {
      localizations?[languageCode]?.variations = Variations()
    }

    if localizations?[languageCode]?.variations?.device == nil {
      localizations?[languageCode]?.variations?.device = [:]
    }

    let variation = Variation(
      stringUnit: StringUnit(state: state, value: value)
    )
    localizations?[languageCode]?.variations?.device?[deviceType] = variation
  }
}

// MARK: - Localization Extensions
extension Localization {
  // Initialize with standard string unit
  init(value: String = "", state: StringUnitState = .new) {
    self.stringUnit = StringUnit(state: state, value: value)
  }

  // Check if localization is empty (no translations)
  func isEmpty() -> Bool {
    if stringUnit == nil && variations == nil {
      return true
    }

    if let stringUnit = stringUnit, !stringUnit.value.isEmpty {
      return false
    }

    if let variations = variations {
      if let plural = variations.plural, !plural.isEmpty {
        return false
      }

      if let device = variations.device, !device.isEmpty {
        return false
      }
    }

    return true
  }

  // Get all string values (for regular, plural and device variations)
  func getAllValues() -> [String] {
    var values: [String] = []

    if let unit = stringUnit {
      values.append(unit.value)
    }

    if let plural = variations?.plural {
      values.append(contentsOf: plural.values.map { $0.stringUnit.value })
    }

    if let device = variations?.device {
      values.append(contentsOf: device.values.map { $0.stringUnit.value })
    }

    return values
  }

  // Update the state for all variations
  mutating func updateState(_ state: StringUnitState) {
    stringUnit?.state = state

    if var plural = variations?.plural {
      for key in plural.keys {
        plural[key]?.stringUnit.state = state
      }
      variations?.plural = plural
    }

    if var device = variations?.device {
      for key in device.keys {
        device[key]?.stringUnit.state = state
      }
      variations?.device = device
    }
  }

  // Create a copy of another localization but with a new state
  static func copyWithNewState(
    from source: Localization,
    state: StringUnitState
  ) -> Localization {
    var copy = source
    copy.updateState(state)
    return copy
  }
}

// MARK: - FileLoadingModel Extensions
extension FileLoadingModel {
  // Add a new key to the localization file
  func addKey(_ key: String, comment: String? = nil) -> Bool {
    guard var file = localizationFile else {
      return false
    }

    if file.strings[key] == nil {
      var stringSet = StringSet()
      stringSet.comment = comment
      stringSet.localizations = [:]

      // Initialize with source language
      let sourceLang = file.sourceLanguage
      let sourceLocalization = Localization(value: key, state: .new)
      stringSet.localizations?[sourceLang] = sourceLocalization

      // Initialize empty localizations for all existing languages
      for language in file.getAllLanguages() where language != sourceLang {
        stringSet.localizations?[language] = Localization()
      }

      file.strings[key] = stringSet
      localizationFile = file
      return true
    }

    return false
  }

  // Remove a key from the localization file
  func removeKey(_ key: String) -> Bool {
    guard var file = localizationFile, file.strings[key] != nil else {
      return false
    }

    file.strings.removeValue(forKey: key)
    localizationFile = file
    return true
  }

  // Get all keys that need translation for a specific language
  func getKeysNeedingTranslation(for languageCode: String) -> [String] {
    guard let file = localizationFile else {
      return []
    }

    return file.getMissingTranslations(for: languageCode)
  }

  // Set a simple translation for a key and language
  @discardableResult
  func setTranslation(
    key: String,
    language: String,
    value: String,
    state: StringUnitState = .translated
  ) -> Bool {
    guard var file = localizationFile, var stringSet = file.strings[key] else {
      return false
    }

    if stringSet.localizations == nil {
      stringSet.localizations = [:]
    }

    if stringSet.localizations?[language] == nil {
      stringSet.localizations?[language] = Localization()
    }

    stringSet.localizations?[language]?.stringUnit = StringUnit(
      state: state,
      value: value
    )

    file.strings[key] = stringSet
    localizationFile = file
    return true
  }

  // Set a plural translation for a key
  @discardableResult
  func setPluralTranslation(
    key: String,
    language: String,
    pluralForm: String,
    value: String,
    state: StringUnitState = .translated
  ) -> Bool {
    guard var file = localizationFile, var stringSet = file.strings[key] else {
      return false
    }

    if stringSet.localizations == nil {
      stringSet.localizations = [:]
    }

    if stringSet.localizations?[language] == nil {
      stringSet.localizations?[language] = Localization()
    }

    if stringSet.localizations?[language]?.variations == nil {
      stringSet.localizations?[language]?.variations = Variations()
    }

    if stringSet.localizations?[language]?.variations?.plural == nil {
      stringSet.localizations?[language]?.variations?.plural = [:]
    }

    // Only add non-empty values
    if !value.isEmpty {
      let variation = Variation(
        stringUnit: StringUnit(state: state, value: value)
      )
      stringSet.localizations?[language]?.variations?.plural?[pluralForm] =
        variation
    } else {
      // Remove empty values to keep the file clean
      stringSet.localizations?[language]?.variations?.plural?.removeValue(
        forKey: pluralForm
      )

      // Clean up if plural dict is now empty
      if stringSet.localizations?[language]?.variations?.plural?.isEmpty == true
      {
        stringSet.localizations?[language]?.variations?.plural = nil

        // Clean up variations if both plural and device are empty/nil
        if stringSet.localizations?[language]?.variations?.device == nil {
          stringSet.localizations?[language]?.variations = nil
        }
      }
    }

    file.strings[key] = stringSet
    localizationFile = file
    return true
  }

  // Set a device-specific translation for a key
  @discardableResult
  func setDeviceTranslation(
    key: String,
    language: String,
    deviceType: String,
    value: String,
    state: StringUnitState = .translated
  ) -> Bool {
    guard var file = localizationFile, var stringSet = file.strings[key] else {
      return false
    }

    if stringSet.localizations == nil {
      stringSet.localizations = [:]
    }

    if stringSet.localizations?[language] == nil {
      stringSet.localizations?[language] = Localization()
    }

    if stringSet.localizations?[language]?.variations == nil {
      stringSet.localizations?[language]?.variations = Variations()
    }

    if stringSet.localizations?[language]?.variations?.device == nil {
      stringSet.localizations?[language]?.variations?.device = [:]
    }

    // Only add non-empty values
    if !value.isEmpty {
      let variation = Variation(
        stringUnit: StringUnit(state: state, value: value)
      )
      stringSet.localizations?[language]?.variations?.device?[deviceType] =
        variation
    } else {
      // Remove empty values to keep the file clean
      stringSet.localizations?[language]?.variations?.device?.removeValue(
        forKey: deviceType
      )

      // Clean up if device dict is now empty
      if stringSet.localizations?[language]?.variations?.device?.isEmpty == true
      {
        stringSet.localizations?[language]?.variations?.device = nil

        // Clean up variations if both plural and device are empty/nil
        if stringSet.localizations?[language]?.variations?.plural == nil {
          stringSet.localizations?[language]?.variations = nil
        }
      }
    }

    file.strings[key] = stringSet
    localizationFile = file
    return true
  }
}

// Extension methods needed for FileLoadingModel
extension FileLoadingModel {
  // Clear a standard translation
  func clearTranslation(key: String, language: String) {
    guard var file = localizationFile, var stringSet = file.strings[key] else {
      return
    }

    if var localization = stringSet.localizations?[language] {
      localization.stringUnit = nil
      stringSet.localizations?[language] = localization
    }

    file.strings[key] = stringSet
    localizationFile = file
  }

  // Clear all variations
  func clearVariations(key: String, language: String) {
    guard var file = localizationFile, var stringSet = file.strings[key] else {
      return
    }

    if var localization = stringSet.localizations?[language] {
      localization.variations = nil
      stringSet.localizations?[language] = localization
    }

    file.strings[key] = stringSet
    localizationFile = file
  }
  
  // Add a new language to the localization file
  func addLanguage(_ languageCode: String) {
	guard var file = localizationFile else { return }
	
	// Validate that the language doesn't already exist
	let existingLanguages = Set(
	  file.strings.values
		.compactMap(\.localizations)
		.flatMap(\.keys)
		.map { $0 as String }
	)
	
	guard !existingLanguages.contains(languageCode) else {
	  return
	}
	
	// Initialize the language by adding an empty localization to at least one key
	// We'll add it to all keys that have the source language
	for (key, _) in file.strings {
	  // Only add to keys that should be translated
	  guard file.strings[key]?.shouldTranslate ?? true else { continue }
	  
	  // Initialize with an empty, untranslated state
	  if file.strings[key]?.localizations == nil {
		file.strings[key]?.localizations = [:]
	  }
	  
	  file.strings[key]?.localizations?[languageCode] = Localization(
		stringUnit: StringUnit(
		  state: .notTranslated,
		  value: ""
		),
		variations: nil
	  )
	}
	
	// Update the file
	localizationFile = file
  }

  // Remove a specific plural form
  func removePluralForm(key: String, language: String, pluralForm: String) {
    guard var file = localizationFile, var stringSet = file.strings[key] else {
      return
    }

    // Remove the plural form
    stringSet.localizations?[language]?.variations?.plural?.removeValue(
      forKey: pluralForm
    )

    // Clean up if the plural dictionary is now empty
    if stringSet.localizations?[language]?.variations?.plural?.isEmpty == true {
      stringSet.localizations?[language]?.variations?.plural = nil
    }

    file.strings[key] = stringSet
    localizationFile = file
  }

  // Remove a specific device type
  func removeDeviceType(key: String, language: String, deviceType: String) {
    guard var file = localizationFile, var stringSet = file.strings[key] else {
      return
    }

    // Remove the device type
    stringSet.localizations?[language]?.variations?.device?.removeValue(
      forKey: deviceType
    )

    // Clean up if the device dictionary is now empty
    if stringSet.localizations?[language]?.variations?.device?.isEmpty == true {
      stringSet.localizations?[language]?.variations?.device = nil
    }

    file.strings[key] = stringSet
    localizationFile = file
  }

  // Clean up empty structures
  func cleanEmptyStructures(key: String, language: String) {
    guard var file = localizationFile, var stringSet = file.strings[key] else {
      return
    }

    // Check if variations exists but both plural and device are nil/empty
    if let variations = stringSet.localizations?[language]?.variations,
      variations.plural == nil || variations.plural?.isEmpty == true,
      variations.device == nil || variations.device?.isEmpty == true
    {
      // Remove the entire variations structure
      stringSet.localizations?[language]?.variations = nil
    }

    // Check if localization is completely empty and can be removed
    if stringSet.localizations?[language]?.isEmpty() == true {
      stringSet.localizations?.removeValue(forKey: language)
    }

    // Update the string set
    file.strings[key] = stringSet
    localizationFile = file
  }
}

extension FileLoadingModel {
  // Copy translations from one language to another
  func copyTranslations(
    from sourceLanguage: String,
    to targetLanguage: String,
    overwriteExisting: Bool = false,
    newState: StringUnitState = .needsReview
  ) -> Int {
    guard var file = localizationFile else {
      return 0
    }

    var copiedCount = 0

    for (key, var stringSet) in file.strings {
      // Skip keys that shouldn't be translated
      guard stringSet.shouldTranslate != false else { continue }

      if let sourceLocalization = stringSet.localizations?[sourceLanguage] {
        // Check if target language exists or needs to be created
        if stringSet.localizations?[targetLanguage] == nil {
          stringSet.localizations?[targetLanguage] = Localization()
        }

        // Copy regular string unit if it exists
        if let sourceUnit = sourceLocalization.stringUnit,
          overwriteExisting
            || stringSet.localizations?[targetLanguage]?.stringUnit == nil
        {
          let targetUnit = StringUnit(state: newState, value: sourceUnit.value)
          stringSet.localizations?[targetLanguage]?.stringUnit = targetUnit
          copiedCount += 1
        }

        // Copy plural variations if they exist
        if let sourcePlurals = sourceLocalization.variations?.plural,
          !sourcePlurals.isEmpty
        {
          if stringSet.localizations?[targetLanguage]?.variations == nil {
            stringSet.localizations?[targetLanguage]?.variations = Variations()
          }

          if stringSet.localizations?[targetLanguage]?.variations?.plural == nil
          {
            stringSet.localizations?[targetLanguage]?.variations?.plural = [:]
          }

          for (pluralForm, sourceVariation) in sourcePlurals {
            if overwriteExisting
              || stringSet.localizations?[targetLanguage]?.variations?.plural?[
                pluralForm
              ] == nil
            {
              let targetVariation = Variation(
                stringUnit: StringUnit(
                  state: newState,
                  value: sourceVariation.stringUnit.value
                )
              )
              stringSet.localizations?[targetLanguage]?.variations?.plural?[
                pluralForm
              ] = targetVariation
            }
          }
        }

        // Copy device variations if they exist
        if let sourceDevices = sourceLocalization.variations?.device,
          !sourceDevices.isEmpty
        {
          if stringSet.localizations?[targetLanguage]?.variations == nil {
            stringSet.localizations?[targetLanguage]?.variations = Variations()
          }

          if stringSet.localizations?[targetLanguage]?.variations?.device == nil
          {
            stringSet.localizations?[targetLanguage]?.variations?.device = [:]
          }

          for (deviceType, sourceVariation) in sourceDevices {
            if overwriteExisting
              || stringSet.localizations?[targetLanguage]?.variations?.device?[
                deviceType
              ] == nil
            {
              let targetVariation = Variation(
                stringUnit: StringUnit(
                  state: newState,
                  value: sourceVariation.stringUnit.value
                )
              )
              stringSet.localizations?[targetLanguage]?.variations?.device?[
                deviceType
              ] = targetVariation
            }
          }
        }

        file.strings[key] = stringSet
      }
    }

    localizationFile = file
    return copiedCount
  }

  // Helper method to auto-detect and create plural forms for a key
  func detectAndCreatePluralForms(for key: String, language: String) -> Bool {
    guard var file = localizationFile, var stringSet = file.strings[key] else {
      return false
    }

    // Only do this for strings that look like plurals
    guard
      key.contains("%")
        && (key.lowercased().contains("items")
          || key.lowercased().contains("songs")
          || key.lowercased().contains("files")
          || key.range(of: "%[\\d.]*[@dlu]", options: .regularExpression) != nil)
    else {
      return false
    }

    // Get the common plural forms for this language
    let pluralForms = PluralForm.formsFor(languageCode: language)

    // If there's already a standard string unit, use it as the "other" form
    if let existingUnit = stringSet.localizations?[language]?.stringUnit {
      // Create the "other" plural form if it doesn't exist
      if stringSet.localizations?[language]?.variations?.plural?[
        PluralForm.other.rawValue
      ] == nil {
        stringSet.setPluralTranslation(
          for: language,
          pluralForm: PluralForm.other.rawValue,
          value: existingUnit.value,
          state: existingUnit.state
        )

        // Remove the standard string unit since we're moving to plural forms
        stringSet.localizations?[language]?.stringUnit = nil
      }
    }

    // Ensure all required plural forms exist
    for form in pluralForms {
      if stringSet.localizations?[language]?.variations?.plural?[form.rawValue]
        == nil
      {
        // For "one" form, try to create a singular version if it doesn't exist
        if form == .one {
          // Get the "other" form value to try to create a singular form
          if let otherValue = stringSet.localizations?[language]?.variations?
            .plural?[PluralForm.other.rawValue]?.stringUnit.value
          {
            // Basic English singular form generation (very simplified example)
            var singularValue = otherValue

            // Replace common plural endings
            if singularValue.hasSuffix("s") && !singularValue.hasSuffix("ss") {
              singularValue = String(singularValue.dropLast())
            }

            stringSet.setPluralTranslation(
              for: language,
              pluralForm: form.rawValue,
              value: singularValue,
              state: .needsReview  // Mark as needs review since it's an auto-generated guess
            )
          } else {
            // No other form to derive from, create a default placeholder
            stringSet.setPluralTranslation(
              for: language,
              pluralForm: form.rawValue,
              value: key.replacingOccurrences(of: "s ", with: " "),
              state: .needsReview
            )
          }
        } else {
          // For other forms, just create empty entries
          stringSet.setPluralTranslation(
            for: language,
            pluralForm: form.rawValue,
            value: "",
            state: .new
          )
        }
      }
    }

    file.strings[key] = stringSet
    localizationFile = file
    return true
  }
}
