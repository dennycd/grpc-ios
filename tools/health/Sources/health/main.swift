import ArgumentParser

struct Health: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "OSS Project Health Command Line Tool",
    subcommands: [
      Test.self,
      General.self,
      Maintainability.self,
    ])

  init() {}
}

Health.main()

struct Test: ParsableCommand {
  @Flag(help: "Include a counter with each repetition.")
  var includeCounter = false

  @Option(name: .shortAndLong, help: "The number of times to repeat 'phrase'.")
  var count: Int?

  @Argument(help: "The phrase to repeat.")
  var phrase: String

  mutating func run() throws {
    let repeatCount = count ?? 2

    for i in 1...repeatCount {
      if includeCounter {
        print("\(i): \(phrase)")
      } else {
        print(phrase)
      }
    }
  }

}
