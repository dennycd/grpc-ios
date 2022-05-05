import ArgumentParser
import Foundation
import Rainbow

private let VERBOSE = true
private func debug(_ content: Any) {
  if VERBOSE { print(content) }
}

struct General: ParsableCommand {
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
    debug("analyzing general stats for \(lang) in range \(self.dateRange)".yellow)

    let client1 = NetworkClient()
    client1.fetchIssues(lang: lang) { issues in
      self.issueCreated(issues)
      self.issueClosed(issues)
      self.issueOpen(issues)
    }

    self.prsCreated()
    self.prsClosed()
    self.prsOpen()

    RunLoop.current.run()
  }


    private let createDateFilter: NetworkClient.FetchIssueFilter = { (issue: Issue) -> Bool in
      let createDate = DateHelper.shared.normalizedDate(isoString: issue.created_at)
      return self.dateRange.contains(createDate)
    }

}

// General Metrics

extension General {

  // compute total new issue created within time range
  func issueCreated(_ issues: [Issue]) {
    let count = issues.reduce(0) {
      let createDate = DateHelper.shared.normalizedDate(isoString: $1.created_at)
      let incre = self.dateRange.contains(createDate) ? 1 : 0
      // if incre == 1 { debug($1) }
      return $0 + incre
    }

    debug("[GENERAL]: \(count) new issues created in time range".green)
  }

  // total issues closed in time range
  func issueClosed(_ issues: [Issue]) {
    let count = issues.reduce(0) { count, issue in
      guard let closedStr = issue.closed_at else { return count }
      let closedDate = DateHelper.shared.normalizedDate(isoString: closedStr)
      let incre = self.dateRange.contains(closedDate) ? 1 : 0
      return count + incre
    }

    debug("[GENERAL]: \(count) issues closed in time range, including issues created piror to time range".green)
  }

  // total issues that are
  //   -  created on & after the start date
  //   -  still remain open on the end date
  func issueOpen(_ issues: [Issue]) {
    let count = issues.reduce(0) {
      // issue should have been created prior or on end date
      // issue should have been created on and after start date
      let createDate = DateHelper.shared.normalizedDate(isoString: $1.created_at)
      guard self.dateRange.contains(createDate) else { return $0 }

      var incre = 0
      // if issue has been closed, but is closed after end date, consider as opned for the time range
      if let closeDateStr = $1.closed_at {
        let closeDate = DateHelper.shared.normalizedDate(isoString: closeDateStr)
        incre = closeDate > self.dateRange.endDate ? 1 : 0
      } else {
        // issue still open, count
        incre = 1
      }
      return $0 + incre
    }

    debug("[GENERAL]: \(count) issues remain open on \(self.dateRange.endDate.formatted())".green)
  }

  // total PRs created in time range
  func prsCreated() {

    // only look at PRs created within the date range
    let client2 = NetworkClient()
    client2.fetchPRs(lang: lang, filter: self.createDateFilter) { prs in
      debug("[GENERAL]: \(prs.count) new pull requests created in time range".green)
    }

  }

  // total PRs merged in time range
  func prsClosed() {

      let client = NetworkClient()
      client.fetchPRs(lang: lang, filter: self.createDateFilter) { prs in
        let count = prs.reduce(0) {
            guard let closeAt = $1.merged_at else { return $0 }
            let closeDate = DateHelper.shared.normalizedDate(isoString: closeAt)
            let incre = closeDate <= self.dateRange.endDate ? 1 : 0
            return $0 + incre
        }

        debug("[GENERAL]: \(count) pull requests merged in time range".green)
      }

  }

    //  // total PRs still open by the end of the time range
    func prsOpen() {

    }


}
