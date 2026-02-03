//
//  EditorView.swift
//  xcstring-tool
//
//  Created by Lakhan Lothiyi on 14/04/2025.
//

import Foundation
import Observation
import SwiftTUI

@Observable
class EditorViewModel {
  static let shared = EditorViewModel()
  @ObservationIgnored
  let fileVM: FileLoadingModel = .shared
  let currentLocale = Locale.current

  private init() {
    self.fileVM.newFileLoadedCallback = { file in
      self.isShowingMenu = false
      self.selectedLanguage = file.sourceLanguage
      self.selectedKey = nil
      self.selectedLocalizationForDeletion = nil
      self.isAddingNewLanguage = false
    }
  }

  var isShowingMenu: Bool = false

  var selectedLanguage: String = ""
  var selectedKey: String? = nil {
    didSet {
      self.editorShowCallback?(selectedKey != nil)
    }
  }
  var selectedLocalizationForDeletion: String? = nil
  var isAddingNewLanguage: Bool = false

  var editorShowCallback: ((Bool) -> Void)? = nil
}

struct EditorView: View {
  var editorViewModel = EditorViewModel.shared
  let currentLocale = Locale.current

  var file: LocalizationFile? {
    get {
      editorViewModel.fileVM.localizationFile
    }
    set {
      editorViewModel.fileVM.localizationFile = newValue
    }
  }

  @State var isShowingLocalizationEditor = false

  init() {
    editorViewModel.selectedLanguage =
      file?.sourceLanguage ?? editorViewModel.selectedLanguage
  }

  var body: some View {
    HStack {
      sidebar
        .frame(width: 25)

      if self.editorViewModel.isShowingMenu {
        menu
      } else {
        editor
      }
    }
    .onAppear {
      self.editorViewModel.editorShowCallback = {
        self.isShowingLocalizationEditor = $0
      }
    }
  }

  @ViewBuilder var sidebar: some View {
    VStack {
      VStack {
        Text("\(file?.strings.count ?? 0) Localizations")
        Text("Base Lang: \(file?.sourceLanguage ?? "")")
      }
      .frame(maxWidth: .infinity)
      .border(style: .rounded)

      VStack {
        VStack {
          if editorViewModel.selectedLocalizationForDeletion != nil {
            sidebarRemoveLanguage
          } else if editorViewModel.isAddingNewLanguage {
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
              editorViewModel.isAddingNewLanguage == false
                && editorViewModel.selectedLocalizationForDeletion == nil
            else { return }
            self.editorViewModel.isAddingNewLanguage = true
          }
          .bold()

          if editorViewModel.selectedLanguage != file?.sourceLanguage {
            Button(" - ") {
              guard
                editorViewModel.isAddingNewLanguage == false
                  && editorViewModel.selectedLocalizationForDeletion == nil
              else { return }
              self.editorViewModel.selectedLocalizationForDeletion =
                editorViewModel.selectedLanguage
            }
            .bold()
          } else {
            Text(" - ")
              .bold()
              .foregroundColor(.gray)
          }

          Spacer()

          Text(
            "\(Set((file?.strings.values.compactMap(\.localizations).flatMap(\.keys).map { $0 as String }) ?? []).count) Languages"
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
          editorViewModel.selectedKey = nil

          editorViewModel.isShowingMenu.toggle()
        }
        .bold(editorViewModel.isShowingMenu)

        Divider()

        ForEach(
          Array(
            Set(
              file?.strings.values.compactMap(\.localizations).flatMap(
                \.keys
              )
              .map { $0 as String } ?? []
            )
          )
          .sorted { lhs, rhs in
            if lhs == file?.sourceLanguage { return true }
            if rhs == file?.sourceLanguage { return false }
            return lhs < rhs
          },
          id: \.self
        ) { identifier in
          let language =
            currentLocale.localizedString(forIdentifier: identifier)
            ?? identifier
          Button(" \(language) ") {
            self.editorViewModel.selectedKey = nil
            self.editorViewModel.selectedLanguage = identifier
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(
            editorViewModel.selectedLanguage == identifier
              ? Color.gray : .default
          )
        }
      }
      .frame(width: 25)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @State var foundLangs: [Locale.LanguageCode] = Locale.allLanguageCodes()
  @ViewBuilder var sidebarAddLanguage: some View {
    VStack(alignment: .center) {
      Text("Add New Language")
      Divider()
      TextField(placeholder: "Search...", initialValue: "") { _ in
      } update: { newValue in
        let allLangs = Locale.allLanguageCodes()
        if newValue.isEmpty {
          self.foundLangs = allLangs
        } else {
          self.foundLangs = allLangs.filter {
            (currentLocale.localizedString(forIdentifier: $0.identifier) ?? "")
              .localizedCaseInsensitiveContains(newValue)
              || currentLocale.identifier.localizedCaseInsensitiveContains(newValue)
          }
		  .sorted { lhs, rhs in
			let lhsName = currentLocale.localizedString(forIdentifier: lhs.identifier) ?? lhs.identifier
			let rhsName = currentLocale.localizedString(forIdentifier: rhs.identifier) ?? rhs.identifier
			return lhsName < rhsName
		  }
        }
      }
      .disableAction(true)
      .environment(\.placeholderColor, .gray)
	  .onAppear {
		foundLangs = Locale.allLanguageCodes()
	  }

      Button(" Cancel ") {
        self.editorViewModel.isAddingNewLanguage = false
      }
      Divider()
      ScrollView {
        ForEach(foundLangs, id: \.identifier) { locale in
          let identifier = locale.identifier
          let language = currentLocale.localizedString(
            forIdentifier: identifier
          )

          Button(language ?? identifier) {
            self.editorViewModel.selectedLanguage = identifier
            self.editorViewModel.fileVM.addLanguage(identifier)
            self.editorViewModel.isAddingNewLanguage = false
          }
        }
      }
    }
  }

  @ViewBuilder var sidebarRemoveLanguage: some View {
    VStack(alignment: .center) {
      Text("Delete \(editorViewModel.selectedLocalizationForDeletion ?? "")?")

      VStack(alignment: .center) {

        Button(" Delete ") {
          fatalError("unimplemented")
        }
        .foregroundColor(.red)

        Divider()

        Button(" Cancel ") {
          self.editorViewModel.selectedLocalizationForDeletion = nil
        }
      }
      .border(.rounded)
      .padding()
    }
  }

  @ViewBuilder var menu: some View {
    VStack(alignment: .center) {
      Text(editorViewModel.fileVM.file?.path ?? "")
        .padding(.bottom)
      VStack(alignment: .center) {
        Button(" Save and exit ") {
          self.editorViewModel.fileVM.reset(save: true)
        }
        .bold()
        .padding()

        Divider()

        Button(" Exit without saving ") {
          self.editorViewModel.fileVM.reset(save: false)
        }
        .padding()
        .foregroundColor(.red)
      }
      .border(style: .rounded)
      .padding(.horizontal)

      Button(" Back ") {
        editorViewModel.isShowingMenu.toggle()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .border(style: .rounded)
  }

  @ViewBuilder var editor: some View {
    GeometryReader { size in
      VStack {
        Group {
          if isShowingLocalizationEditor {
            LocalizationEditor()
          } else {
            localisationsList(size)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        Divider()
        HStack {
          let total = file?.strings.count ?? 0
          let translated =
            file?.strings.filter {
              $0.value.localizations?[editorViewModel.selectedLanguage]?
                .getState(
                  isBaseLanguage: editorViewModel.selectedLanguage
                    == self.file?.sourceLanguage
                ) == .translated || $0.value.shouldTranslate == false
            }.count ?? 0
          if editorViewModel.selectedLanguage != file?.sourceLanguage {
            Text("\(translated)/\(total) Localizations")
          } else {
            Text("\(file?.strings.count ?? 0) Localizations")
          }
          // show currently selected lang
          let language =
            currentLocale.localizedString(
              forIdentifier: editorViewModel.selectedLanguage
            ) ?? editorViewModel.selectedLanguage
          Text(" \(language) ")
            .foregroundColor(.gray)
          Spacer()
          if editorViewModel.selectedLanguage != file?.sourceLanguage {
            let percentage: Int = {
              // calculate percentage of completed translations for the selected language
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

  func localisationsList(_ size: Size) -> some View {
    ScrollView {
      HStack {
        VStack {
          ForEach(
            file?.strings.sorted(by: { $0.key < $1.key }) ?? [],
            id: \.key
          ) {
            key,
            stringSet in

            if stringSet.shouldTranslate == false {
              Text("Don't translate")
                .foregroundColor(.red)
                .bold()
            } else {
              let localisation = stringSet.localizations?[
                editorViewModel.selectedLanguage
              ]
              switch localisation?.getState(
                isBaseLanguage: editorViewModel.selectedLanguage
                  == self.file?.sourceLanguage
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
          ForEach(
            file?.strings.sorted(by: { $0.key < $1.key }) ?? [],
            id: \.key
          ) {
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
              editorViewModel.selectedKey = key
            }
            .foregroundColor(text.isEmpty ? .gray : .default)
          }
        }
      }
    }
  }
}

struct LocalizationEditor: View {

  // MARK: - State
  var fileLoadingModel: FileLoadingModel = .shared
  var editorViewModel: EditorViewModel = .shared
  var localization: StringSet {
    if let key = editorViewModel.selectedKey,
      let value = (fileLoadingModel.localizationFile?.strings[key])
    {
      return value
    } else {
      return .init()
    }
  }
  var selectedLanguage: String {
    editorViewModel.selectedLanguage
  }

  // State for tracking the edited values
  @State var pluralValues: [String: String] = [:]
  @State var deviceValues: [String: String] = [:]

  @State var showPluralEditor: Bool = false
  @State var showDeviceEditor: Bool = false
  @State var showOptionsView: Bool = false
  @State var hasUnsavedChanges: Bool = false

  @State var translationUnlocked: Bool = false

  @State var customPluralForm: String = ""
  @State var customDeviceType: String = ""

  // Current standard value tracked as a state property to allow edits
  @State var currentValue: String = ""

  // Track if we're switching from standard to variations
  @State var hadStandardValueBeforeSwitching: Bool = false

  init() {
    // Set the current value from the localization
    _currentValue = .init(initialValue: initialValue)
    _hadStandardValueBeforeSwitching = .init(
      initialValue: !initialValue.isEmpty
    )

    // Load plural variations
    var pluralValues = [String: String]()
    if let pluralVariations = localization.localizations?[selectedLanguage]?
      .variations?.plural
    {
      for (form, variation) in pluralVariations {
        pluralValues[form] = variation.stringUnit.value
      }
    }

    // Load device variations
    var deviceValues = [String: String]()
    if let deviceVariations = localization.localizations?[selectedLanguage]?
      .variations?.device
    {
      for (device, variation) in deviceVariations {
        deviceValues[device] = variation.stringUnit.value
      }
    }

    _pluralValues = .init(initialValue: pluralValues)
    _deviceValues = .init(initialValue: deviceValues)

    // Set editors based on existing data
    _showPluralEditor = .init(initialValue: hasExistingPluralVariations)
    _showDeviceEditor = .init(initialValue: hasExistingDeviceVariations)
    _hasUnsavedChanges = .init(initialValue: false)

    // Unlock translations by default if not marked as "do not translate"
    _translationUnlocked = .init(
      initialValue: (localization.shouldTranslate ?? true) == true
    )
  }

  // MARK: - Computed properties

  // Valid plural forms
  let validPluralForms = ["zero", "one", "two", "few", "many", "other"]

  // Valid device types
  let validDeviceTypes = [
    "iphone", "ipad", "mac", "tv", "watch", "ipod", "vision", "other",
  ]

  // Get the initial standard value directly from the localization
  var initialValue: String {
    localization.localizations?[selectedLanguage]?.stringUnit?.value
      ?? editorViewModel.selectedKey ?? ""
  }

  // Determine if we should show the standard editor
  var shouldShowStandardEditor: Bool {
    return !showPluralEditor && !showDeviceEditor
  }

  // Available plural forms for the selected language
  var availablePluralForms: [String] {
    // Get language-specific plural forms
    let forms = PluralForm.formsFor(languageCode: selectedLanguage).map(
      \.rawValue
    )

    // If there are existing plural variations, include those too
    if let existingPlurals = localization.localizations?[selectedLanguage]?
      .variations?.plural?.keys
    {
      return Array(Set(forms).union(Set(existingPlurals))).sorted()
    }

    return forms.sorted()
  }

  // Available device types
  var availableDeviceTypes: [String] {
    // If there are existing device variations, include those
    if let existingDevices = localization.localizations?[selectedLanguage]?
      .variations?.device?.keys
    {
      return Array(
        Set(DeviceType.allCases.map(\.rawValue)).union(Set(existingDevices))
      ).sorted()
    }

    return DeviceType.allCases.map(\.rawValue).sorted()
  }

  // Check if this key appears to need pluralization
  var shouldShowPluralOption: Bool {
    return editorViewModel.selectedKey?.contains("%") == true
      && (editorViewModel.selectedKey?.lowercased().contains("songs") == true
        || editorViewModel.selectedKey?.lowercased().contains("items") == true
        || editorViewModel.selectedKey?.lowercased().contains("files") == true
        || editorViewModel.selectedKey?.range(
          of: "%[\\d.]*[@dlu]",
          options: .regularExpression
        )
          != nil)
  }

  // Check if key has existing variations
  var hasExistingPluralVariations: Bool {
    return localization.localizations?[selectedLanguage]?.variations?.plural
      != nil
      && localization.localizations?[selectedLanguage]?.variations?.plural?
        .isEmpty == false
  }

  var hasExistingDeviceVariations: Bool {
    return localization.localizations?[selectedLanguage]?.variations?.device
      != nil
      && localization.localizations?[selectedLanguage]?.variations?.device?
        .isEmpty == false
  }

  // MARK: - Methods

  // Save changes back to model
  func saveChanges() {
    // Skip saving if this is a "do not translate" key and hasn't been unlocked

    // if has changes, was previously locked and is now unlocked, save changes
    if self.hasUnsavedChanges,
      (fileLoadingModel.localizationFile?.strings[editorViewModel.selectedKey!]?
        .shouldTranslate ?? true) == false, translationUnlocked
    {
      // Save the translation with the locked state
      fileLoadingModel.localizationFile?
        .strings[editorViewModel.selectedKey!]?
        .shouldTranslate = true
    }
    if self.hasUnsavedChanges,
      fileLoadingModel.localizationFile?.strings[editorViewModel.selectedKey!]?
        .shouldTranslate ?? true, translationUnlocked == false
    {
      // Save the translation with the locked state
      fileLoadingModel.localizationFile?
        .strings[editorViewModel.selectedKey!]?
        .shouldTranslate = false

      fileLoadingModel.localizationFile?
        .strings[editorViewModel.selectedKey!]?.localizations = nil
      return
    }

    // Determine if we're using variations or standard
    let usesVariations =
      showPluralEditor || showDeviceEditor || !pluralValues.isEmpty
      || !deviceValues.isEmpty

    if usesVariations {
      // Clear the standard value if switching to variations
      if localization.localizations?[selectedLanguage]?.stringUnit != nil {
        fileLoadingModel.clearTranslation(
          key: editorViewModel.selectedKey!,
          language: selectedLanguage
        )
      }

      // For plurals, save all defined forms
      for (form, value) in pluralValues where !form.isEmpty {
        let state = determineState(value: value)
        fileLoadingModel.setPluralTranslation(
          key: editorViewModel.selectedKey!,
          language: selectedLanguage,
          pluralForm: form,
          value: value,
          state: state
        )
      }

      // For device variations, save all defined devices
      for (device, value) in deviceValues where !device.isEmpty {
        let state = determineState(value: value)
        fileLoadingModel.setDeviceTranslation(
          key: editorViewModel.selectedKey!,
          language: selectedLanguage,
          deviceType: device,
          value: value,
          state: state
        )
      }
    } else {
      // Using standard translation - clear any existing variations
      if hasExistingPluralVariations || hasExistingDeviceVariations {
        fileLoadingModel.clearVariations(
          key: editorViewModel.selectedKey!,
          language: selectedLanguage
        )
      }

      // Save standard value if not empty
      if !currentValue.isEmpty {
        let state = determineState(value: currentValue)
        fileLoadingModel.setTranslation(
          key: editorViewModel.selectedKey!,
          language: selectedLanguage,
          value: currentValue,
          state: state
        )
      } else {
        // Clear the standard value if it's empty
        fileLoadingModel.clearTranslation(
          key: editorViewModel.selectedKey!,
          language: selectedLanguage
        )
      }
    }

    hasUnsavedChanges = false
  }

  // Determine state based on values
  func determineState(value: String) -> StringUnitState {
    if selectedLanguage == fileLoadingModel.localizationFile?.sourceLanguage {
      return .none
    }

    // Check if this is duplicate of another language
    let otherLanguages = Array(
      Set(
        (fileLoadingModel.localizationFile?.getAllLanguages() ?? [])
          .filter { $0 != selectedLanguage }
      )
    )

    for language in otherLanguages {
      let values =
        fileLoadingModel.localizationFile?.strings[
          editorViewModel.selectedKey!
        ]?.localizations?[
          language
        ]?.getAllValues() ?? []
      if values.contains(value) {
        return .needsReview
      }
    }

    return .translated
  }

  // Check if values have duplicates within the same language (across plural/device forms)
  func checkForDuplicatesAndMarkNeedsReview() {
    let allValues =
      pluralValues.values.filter({ !$0.isEmpty })
      + deviceValues.values.filter({ !$0.isEmpty })

    // Find duplicates and mark them for review
    if Set(allValues).count != allValues.count {
      // There are duplicates
      for form in pluralValues.keys {
        if pluralValues[form]?.isEmpty == false
          && allValues.filter({ $0 == pluralValues[form] }).count > 1
        {
          // This is a duplicate
          fileLoadingModel.setPluralTranslation(
            key: editorViewModel.selectedKey!,
            language: selectedLanguage,
            pluralForm: form,
            value: pluralValues[form]!,
            state: .needsReview
          )
        }
      }

      for device in deviceValues.keys {
        if deviceValues[device]?.isEmpty == false
          && allValues.filter({ $0 == deviceValues[device] }).count > 1
        {
          // This is a duplicate
          fileLoadingModel.setDeviceTranslation(
            key: editorViewModel.selectedKey!,
            language: selectedLanguage,
            deviceType: device,
            value: deviceValues[device]!,
            state: .needsReview
          )
        }
      }
    }
  }

  // Handle toggling between standard and variations
  func togglePluralEditor(_ enabled: Bool) {
    if enabled && !showPluralEditor {
      // Switching from standard to plural
      if currentValue.isEmpty == false && pluralValues.isEmpty {
        // Propagate the standard value to the "other" form
        pluralValues["other"] = currentValue
        hasUnsavedChanges = true
      }
    }
    showPluralEditor = enabled
  }

  func toggleDeviceEditor(_ enabled: Bool) {
    if enabled && !showDeviceEditor {
      // Switching from standard to device
      if currentValue.isEmpty == false && deviceValues.isEmpty {
        // Propagate the standard value to the "other" form
        deviceValues["other"] = currentValue
        hasUnsavedChanges = true
      }
    }
    showDeviceEditor = enabled
  }

  // Helper methods for adding/removing forms
  func addPluralForm(_ form: String) {
    let trimmedForm = form.lowercased().trimmingCharacters(
      in: .whitespacesAndNewlines
    )

    // Validate plural form
    guard !trimmedForm.isEmpty && validPluralForms.contains(trimmedForm) else {
      return
    }

    // Ensure the form doesn't already exist
    if pluralValues[trimmedForm] == nil {
      pluralValues[trimmedForm] = ""
      hasUnsavedChanges = true

      // Make sure plural editor is enabled when adding forms
      if !showPluralEditor {
        showPluralEditor = true
      }
    }
    customPluralForm = ""
  }

  func removePluralForm(_ form: String) {
    pluralValues.removeValue(forKey: form)
    hasUnsavedChanges = true

    // If no plural forms left, consider disabling plural editor
    if pluralValues.isEmpty && !hasExistingPluralVariations {
      showPluralEditor = false
    }
  }

  func addDeviceType(_ device: String) {
    let trimmedDevice = device.lowercased().trimmingCharacters(
      in: .whitespacesAndNewlines
    )

    // Validate device type
    guard !trimmedDevice.isEmpty && validDeviceTypes.contains(trimmedDevice)
    else {
      return
    }

    // Ensure the device type doesn't already exist
    if deviceValues[trimmedDevice] == nil {
      deviceValues[trimmedDevice] = ""
      hasUnsavedChanges = true

      // Make sure device editor is enabled when adding devices
      if !showDeviceEditor {
        showDeviceEditor = true
      }
    }
    customDeviceType = ""
  }

  func removeDeviceType(_ device: String) {
    deviceValues.removeValue(forKey: device)
    hasUnsavedChanges = true

    // If no device types left, consider disabling device editor
    if deviceValues.isEmpty && !hasExistingDeviceVariations {
      showDeviceEditor = false
    }
  }

  // MARK: - UI Components

  // Header bar with buttons
  var headerBar: some View {
    VStack {
      HStack {
        Button(" Cancel ") {
          if hasUnsavedChanges {
            // In a real app, we'd show a confirmation dialog here
            // but since SwiftTUI doesn't appear to have that, we'll just discard
          }
          self.editorViewModel.selectedKey = nil
        }

        Button(" Save ") {
          saveChanges()
          self.editorViewModel.selectedKey = nil
        }
        .bold()

        Button(" Options ") {
          showOptionsView.toggle()
        }
        .bold(showOptionsView)

        Divider()

        Text("Editing a localization")
      }

      Divider()

      // Variation type selector - only show when we're not in options view
      if !showOptionsView
        && (shouldShowPluralOption || hasExistingPluralVariations
          || hasExistingDeviceVariations || !pluralValues.isEmpty
          || !deviceValues.isEmpty)
      {
        HStack {
          Button(" Standard ") {
            showPluralEditor = false
            showDeviceEditor = false
          }
          .background(
            !showPluralEditor && !showDeviceEditor ? Color.gray : .default
          )

          if shouldShowPluralOption || hasExistingPluralVariations
            || !pluralValues.isEmpty
          {
            Button(" Plurals ") {
              togglePluralEditor(!showPluralEditor)
            }
            .background(showPluralEditor ? Color.gray : .default)
          }

          Button(" Device-Specific ") {
            toggleDeviceEditor(!showDeviceEditor)
          }
          .background(showDeviceEditor ? Color.gray : .default)
        }
        Divider()
      }
    }
    .frame(height: 2)
  }

  // Source text display
  var sourceDisplay: some View {
    VStack(alignment: .leading) {
      Text(
        "Source (\(fileLoadingModel.localizationFile?.sourceLanguage ?? "")):"
      )
      .foregroundColor(.gray)

      let sourceValue =
        localization.localizations?[
          fileLoadingModel.localizationFile?.sourceLanguage ?? ""
        ]?.stringUnit?.value ?? editorViewModel.selectedKey ?? ""

      let text: (isEmpty: Bool, str: String) = {
        if sourceValue.isEmpty { return (true, "(Empty string)") }
        return (
          false,
          sourceValue
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        )
      }()

      Text(text.str)
        .foregroundColor(text.isEmpty ? .gray : .default)

      if let comment = localization.comment {
        Text("Comment: \(comment)")
          .foregroundColor(.gray)
      }

      // Do not translate warning
      if !translationUnlocked {
        Text("⚠️ This key is marked \"Do Not Translate\" ")
          .foregroundColor(.yellow)
          .bold()
          .padding(.top)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(1)
  }

  // Standard translation editor - only show when no variations are active
  var standardEditor: some View {
    VStack(alignment: .leading) {
      Text("Translation for \(selectedLanguage):")
        .bold()
        .foregroundColor(.gray)

      TextField(
        placeholder: initialValue,
        initialValue: currentValue
      ) { newValue in
        currentValue = newValue
        hasUnsavedChanges = true
      } update: { newValue in
        currentValue = newValue
        hasUnsavedChanges = true
      }
    }
    .padding(1)
  }

  // Plural forms editor
  var pluralEditor: some View {
    VStack(alignment: .leading) {
      Text("Plural Forms for \(selectedLanguage):")
        .bold()

      // Show existing plural forms with values
      ForEach(pluralValues.keys.sorted(), id: \.self) { form in
        HStack {
          Text("Form: \(form)")
            .foregroundColor(.gray)

          Spacer()

          Button(" × ") {
            removePluralForm(form)
          }
          .foregroundColor(.red)
        }

        TextField(
          placeholder: "Value for '\(form)' form",
          initialValue: pluralValues[form] ?? ""
        ) { newValue in
          pluralValues[form] = newValue
          hasUnsavedChanges = true
        } update: { newValue in
          pluralValues[form] = newValue
          hasUnsavedChanges = true
        }

        Divider()
      }

      // Show option to add plural form directly from the editor
      HStack {
        TextField(
          placeholder: "Add new plural form...",
          initialValue: customPluralForm
        ) { newValue in
          customPluralForm = newValue
        } update: { newValue in
          customPluralForm = newValue
        }

        if customPluralForm.isEmpty {
          Text(" + ")
            .foregroundColor(.gray)
            .bold()
        } else {
          Button(" + ") {
            addPluralForm(customPluralForm)
          }
          .bold()
        }
      }

      Text("Valid forms: \(validPluralForms.joined(separator: ", "))")
        .foregroundColor(.gray)
    }
    .padding(1)
    .border(style: .rounded)
  }

  // Device variations editor
  var deviceEditor: some View {
    VStack(alignment: .leading) {
      Text("Device Variations for \(selectedLanguage):")
        .bold()

      // Show existing device types with values
      ForEach(deviceValues.keys.sorted(), id: \.self) { device in
        HStack {
          Text("Device: \(device)")
            .foregroundColor(.gray)

          Spacer()

          Button(" × ") {
            removeDeviceType(device)
          }
          .foregroundColor(.red)
        }

        TextField(
          placeholder: "Value for '\(device)'",
          initialValue: deviceValues[device] ?? ""
        ) { newValue in
          deviceValues[device] = newValue
          hasUnsavedChanges = true
        } update: { newValue in
          deviceValues[device] = newValue
          hasUnsavedChanges = true
        }

        Divider()
      }

      // Show option to add device type directly from the editor
      HStack {
        TextField(
          placeholder: "Add new device type...",
          initialValue: customDeviceType
        ) { newValue in
          customDeviceType = newValue
        } update: { newValue in
          customDeviceType = newValue
        }

        if customDeviceType.isEmpty {
          Text(" + ")
            .foregroundColor(.gray)
            .bold()
        } else {
          Button(" + ") {
            addDeviceType(customDeviceType)
          }
          .bold()
        }
      }

      Text("Valid types: \(validDeviceTypes.joined(separator: ", "))")
        .foregroundColor(.gray)
    }
    .padding(1)
    .border(style: .rounded)
  }

  // Options view for additional settings
  var optionsView: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 1) {
        Text("Editor Options")
          .bold()

        Divider()

        // Translation lock option
        HStack {
          Text("Translation Lock:")
            .bold()

          Spacer()

          Button(translationUnlocked ? " Lock " : " Unlock ") {
            translationUnlocked.toggle()
            hasUnsavedChanges = true
          }
          .foregroundColor(translationUnlocked ? .red : .green)
          .bold()
        }

        Text(
          translationUnlocked
            ? "Translation unlocked for this 'Do Not Translate' key"
            : "This key is marked 'Do Not Translate' and is locked"
        )
        .foregroundColor(.gray)

        Divider()

        // Plural forms management
        VStack(alignment: .leading) {
          Text("Manage Plural Forms:")
            .bold()

          HStack {
            TextField(
              placeholder: "New plural form (e.g., 'zero', 'few')",
              initialValue: customPluralForm
            ) { newValue in
              customPluralForm = newValue
            } update: { newValue in
              customPluralForm = newValue
            }

            if customPluralForm.isEmpty {
              Text(" + ")
                .foregroundColor(.gray)
                .bold()
            } else {
              Button(" + ") {
                addPluralForm(customPluralForm)
              }
              .bold()
            }
          }

          Text("Valid forms: \(validPluralForms.joined(separator: ", "))")
            .foregroundColor(.gray)

          if !pluralValues.isEmpty {
            Text("Current plural forms:")
              .bold()

            ForEach(pluralValues.keys.sorted(), id: \.self) { form in
              HStack {
                Text("• \(form)")

                Spacer()

                Button(" Remove ") {
                  removePluralForm(form)
                }
                .foregroundColor(.red)
              }
            }
          }
        }
        .padding(1)
        .border(style: .rounded)

        // Device types management
        VStack(alignment: .leading) {
          Text("Manage Device Types:")
            .bold()

          HStack {
            TextField(
              placeholder: "New device type (e.g., 'vision', 'car')",
              initialValue: customDeviceType
            ) { newValue in
              customDeviceType = newValue
            } update: { newValue in
              customDeviceType = newValue
            }

            if customDeviceType.isEmpty {
              Text(" + ")
                .foregroundColor(.gray)
                .bold()
            } else {
              Button(" + ") {
                addDeviceType(customDeviceType)
              }
              .bold()
            }
          }

          Text("Valid types: \(validDeviceTypes.joined(separator: ", "))")
            .foregroundColor(.gray)

          if !deviceValues.isEmpty {
            Text("Current device types:")
              .bold()

            ForEach(deviceValues.keys.sorted(), id: \.self) { device in
              HStack {
                Text("• \(device)")

                Spacer()

                Button(" Remove ") {
                  removeDeviceType(device)
                }
                .foregroundColor(.red)
              }
            }
          }
        }
        .padding(1)
        .border(style: .rounded)

        // Return button
        HStack {
          Spacer()

          Button(" Back to Editor ") {
            showOptionsView = false
          }
          .bold()

          Spacer()
        }
        .padding(1)
      }
      .padding(1)
    }
  }

  // Status information bar
  var statusBar: some View {
    HStack {
      if hasUnsavedChanges {
        Text("Unsaved changes")
          .foregroundColor(.yellow)
          .bold()
      } else {
        Text("No changes")
          .foregroundColor(.gray)
      }

      Spacer()

      // Display current state of this translation
      let state =
        localization.localizations?[selectedLanguage]?.getState(
          isBaseLanguage: selectedLanguage
            == fileLoadingModel.localizationFile?.sourceLanguage
        ) ?? .notTranslated

      let stateParsed: (text: String, color: Color) = {
        let stateText: String
        let stateColor: Color

        switch state {
        case .notTranslated:
          stateText = "Untranslated"
          stateColor = .red
        case .needsReview:
          stateText = "Needs review"
          stateColor = .yellow
        case .stale:
          stateText = "Stale"
          stateColor = .yellow
        case .new:
          stateText = "New"
          stateColor = .blue
        case .translated:
          stateText = "Translated"
          stateColor = .green
        case .none:
          stateText = "Source"
          stateColor = .default
        }

        return (stateText, stateColor)
      }()

      Text(stateParsed.text)
        .foregroundColor(stateParsed.color)
        .bold()
    }
    .padding(1)
  }

  // Main editor content
  var editorContent: some View {
    VStack {
      sourceDisplay

      Divider()

      if !translationUnlocked {
        // Show locked message
        VStack(spacing: 1) {
          Text("This key is marked as \"Do Not Translate\"")
            .bold()

          Text("Go to Options to unlock this key for translation")
            .foregroundColor(.gray)

          Button(" Unlock ") {
            translationUnlocked = true
            hasUnsavedChanges = true
          }
          .foregroundColor(.red)
          .bold()
          .padding(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        // Main editing area
        ScrollView {
          VStack(spacing: 2) {
            // Show standard editor only when no variations are active
            if shouldShowStandardEditor {
              standardEditor
            }

            // Conditionally show plural and device editors
            if showPluralEditor {
              pluralEditor
            }

            if showDeviceEditor {
              deviceEditor
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  // MARK: - View

  var body: some View {
    VStack(alignment: .center) {
      // Header with buttons
      headerBar

      // Main content area
      if showOptionsView {
        optionsView
      } else {
        editorContent
      }

      Divider()

      // Status bar
      statusBar
    }
  }
}

extension Locale {
  static func allLanguageCodes() -> [Locale.LanguageCode] {
	return .Element.isoLanguageCodes
  }
}
