//
//  PluralForm.swift
//  xcstring-tool
//
//  Created by Lakhan Lothiyi on 14/04/2025.
//

import Foundation

// MARK: - String Utility Extensions
extension String {
  // Determine if this string contains format specifiers
  var containsFormatSpecifiers: Bool {
    return range(
      of: "%[\\d.]*[diuoxXfFeEgGaAcCsSp@]",
      options: .regularExpression
    ) != nil
  }

  // Extract format specifiers from a string
  func extractFormatSpecifiers() -> [String] {
    let pattern = "%[\\d.]*[diuoxXfFeEgGaAcCsSp@]"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return []
    }

    let matches = regex.matches(
      in: self,
      range: NSRange(self.startIndex..., in: self)
    )

    return matches.compactMap { match in
      if let range = Range(match.range, in: self) {
        return String(self[range])
      }
      return nil
    }
  }
}

// MARK: - Common Plural Forms
enum PluralForm: String {
  case zero = "zero"
  case one = "one"
  case two = "two"
  case few = "few"
  case many = "many"
  case other = "other"

  // Get common plural forms for a language code
  static func formsFor(languageCode: String) -> [PluralForm] {
    switch languageCode.lowercased() {
    case "en", "de", "nl", "es", "it":
      return [.one, .other]
    case "fr", "ja", "zh":
      return [.other]
    case "ru", "uk", "pl", "cs":
      return [.one, .few, .many, .other]
    case "ar":
      return [.zero, .one, .two, .few, .many, .other]
    default:
      // Default to the most common plural forms
      return [.one, .other]
    }
  }
}

// MARK: - Common Device Types
enum DeviceType: String {
  case iphone = "iphone"
  case ipod = "ipod"
  case ipad = "ipad"
  case watch = "watch"
  case tv = "tv"
  case mac = "mac"
  case other = "other"

  static var allCases: [DeviceType] {
    return [.iphone, .ipod, .ipad, .watch, .tv, .mac, .other]
  }
}

// MARK: - Translation Statistics
extension LocalizationFile {
  // Get translation statistics for a language
  func getStatistics(for languageCode: String) -> (
    total: Int, translated: Int, needsReview: Int, missing: Int, stale: Int
  ) {
    var total = 0
    var translated = 0
    var needsReview = 0
    var missing = 0
    var stale = 0

    let isBaseLanguage = languageCode == sourceLanguage

    for (_, stringSet) in strings {
      // Skip keys that shouldn't be translated
      guard stringSet.shouldTranslate != false else { continue }
      total += 1

      if let localization = stringSet.localizations?[languageCode] {
        if isBaseLanguage {
          // Source language entries are considered translated
          translated += 1
        } else if localization.isEmpty() {
          missing += 1
        } else {
          // Check the state of all string units
          let units = localization.getAllValues()
          if units.isEmpty {
            missing += 1
          } else {
            switch localization.getState(isBaseLanguage: isBaseLanguage) {
            case .translated:
              translated += 1
            case .needsReview:
              needsReview += 1
            case .stale:
              stale += 1
            case .new:
              // New is considered translated but could be improved
              translated += 1
            default:
              missing += 1
            }
          }
        }
      } else {
        if !isBaseLanguage {
          missing += 1
        }
      }
    }

    return (total, translated, needsReview, missing, stale)
  }
}
