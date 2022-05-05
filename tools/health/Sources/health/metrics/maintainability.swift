import ArgumentParser
import Foundation
import Rainbow

private let VERBOSE = true
private func debug(_ content: Any) {
  if VERBOSE { print(content) }
}

let SECONDS_PER_DAY: Double = 24 * 60 * 60

struct Maintainability: ParsableCommand {
  @Argument(
    help:
      "The project language to pull for stats. Possible values are \(LangLabel.keys.joined(separator:","))"
  )
  var lang: String
  @Option(name: .shortAndLong, help: "The earliest date for issue creation in format YYYY-MM-DD")
  var startDate: String?
  @Option(name: .shortAndLong, help: "The latest date for issue creation in format YYYY-MM-DD")
  var endDate: String?

  // time range from specified parameter
  private var dateRange: DateRange {
    return DateRange(startDateStr: self.startDate, endDateStr: self.endDate)
  }

  func run() throws {
    debug("analyzing maintainability stats for \(lang) in range \(self.dateRange)".yellow)
    NetworkClient.shared.fetchIssues(lang: lang) { issues in
      self.meanResolutionTime(issues)
      self.closeRatio(issues)
    }

    RunLoop.current.run()
  }
}

extension Maintainability {

  // Median time needed to close an issue
  // Issues are
  //   - created on & after the start date range
  //   - closed prior & on the end date ( ignore issues that are still open // closed after the end date)
  func meanResolutionTime(_ issues: [Issue]) {

    let issues = issues.filter {
      // created within raneg
      let createDate = DateHelper.shared.normalizedDate(isoString: $0.created_at)
      guard self.dateRange.contains(createDate) else { return false }

      // has closed within range
      guard let closeDateStr = $0.closed_at else { return false }
      let closeDate = DateHelper.shared.normalizedDate(isoString: closeDateStr)
      guard self.dateRange.contains(closeDate) else { return false }

      return true
    }

    let durations: [TimeInterval] = issues.map {
      let createDate = DateHelper.shared.normalizedDate(isoString: $0.created_at)
      let closeDate = DateHelper.shared.normalizedDate(isoString: $0.closed_at!)
      return closeDate.timeIntervalSince(createDate)
    }
    .sorted(by: <)

    let n = durations.count
    let median = n % 2 == 0 ? (durations[(n - 1) / 2] + durations[n / 2]) / 2 : durations[n / 2]

    debug(
      "[MAINTAINABILITY]: median time to close an issue: \(Int(median / SECONDS_PER_DAY)) days (\(n) issues)"
        .green)

  }

  // Percentage of issues that are closed
  // Issues are
  //   - created within the time range
  func closeRatio(_ issues: [Issue]) {
    var created = 0
    var closed = 0

    issues.forEach {
      // created within range
      let createDate = DateHelper.shared.normalizedDate(isoString: $0.created_at)
      guard self.dateRange.contains(createDate) else { return }
      created += 1

      // +1 if closed in time range
      guard let closeDateStr = $0.closed_at else { return }
      let closeDate = DateHelper.shared.normalizedDate(isoString: closeDateStr)
      closed += self.dateRange.contains(closeDate) ? 1 : 0
    }

    let ratioStr = String(format: "%.2f", Double(closed) / Double(created))
    debug(
      "[MAINTAINABILITY]: percentage of issues that are closed: \(ratioStr)[\(closed)/\(created)]"
        .green)

  }

}
