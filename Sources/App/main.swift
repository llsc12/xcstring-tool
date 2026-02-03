// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import SwiftTUI

let _version = "0.1.0"

if CommandLine.arguments.count < 2 {
  Application(rootView: ContentView()).start()
} else {
  let url = URL(fileURLWithPath: CommandLine.arguments[1])
  if FileManager.default.fileExists(atPath: url.path) {
    let fileLoadingModel = FileLoadingModel.shared
    fileLoadingModel.file = url
  }
  Application(rootView: ContentView()).start()
}
