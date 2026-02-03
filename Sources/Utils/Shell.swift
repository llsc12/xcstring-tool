//
//  Shell.swift
//  xcstring-tool
//
//  Created by Lakhan Lothiyi on 14/04/2025.
//

import Foundation

public struct Shell {

  @discardableResult
  public static func run(
    _ command: String...,
    at path: URL? = nil,
  ) throws -> String? {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.currentDirectoryPath = path?.path ?? URL.currentDirectory().path
    task.arguments = ["-c", command.joined(separator: " ")]
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    task.standardInput = nil

    try task.run()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)

    if output?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
      return nil
    }
    return output
  }
}
