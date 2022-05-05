import Foundation

struct User: Codable {
  let login: String  // log in name
}

enum State: String, Codable {
  case `open`
  case closed
}

struct Issue: Codable {

  struct Label: Codable {
    let name: String
  }

  let title: String
  // let description: String?

  let number: Int
  let state: State

  let user: User?
  let assignee: User?

  let comments: Int

  let created_at: String
  let closed_at: String?
  let updated_at: String?

  let pull_request: [String: String?]?  // nil to indicate not a pull request

}

extension Issue: CustomStringConvertible {
  var description: String {
    "ISSUE[\(number)][\(state)][created: \(created_at)]: \(title) "
  }
}

struct DateRange: CustomStringConvertible {
  let startDate: Date
  let endDate: Date

  init(startDate: Date, endDate: Date) {
    self.startDate = startDate
    self.endDate = endDate
  }

  init(startDateStr: String?, endDateStr: String?) {
    let startD = DateHelper.shared.normalizedDate(startDateStr ?? "1907-01-01")
    let endD =
      endDateStr != nil
      ? DateHelper.shared.normalizedDate(endDateStr!)
      : DateHelper.shared.normalizedDate(date: Date.now)
    self.init(startDate: startD, endDate: endD)
  }

  func contains(_ date: Date) -> Bool {
    return date >= self.startDate && date <= self.endDate
  }

  var description: String {
    "[\(self.startDate.formatted(date: .numeric, time: .omitted)) -- \(self.endDate.formatted(date: .numeric, time: .omitted))]"
  }
}

struct PullRequest: Codable {
  let state: State
  let title: String
  let number: Int

  let comments: Int
  let review_comments: Int
  let commits: Int

  let additions: Int
  let deletions: Int
  let changed_files: Int

  let created_at: String
  let closed_at: String?
  let updated_at: String?
  let merged_at: String?

  let merged: Bool

}

extension PullRequest: CustomStringConvertible {
  var description: String {
    "PULL[\(number)][\(state)][created: \(created_at)]: \(title) "
  }
}
