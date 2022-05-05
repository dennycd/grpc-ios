import Foundation

let GITHUB_TOKEN = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] ?? ""

enum ProjectLang: String, CaseIterable {
  case objc
  case php
  case ruby
}

let LangLabel = [
  "objc": "lang/ObjC",
  "ruby": "lang/ruby",
  "php": "lang/php",
]
