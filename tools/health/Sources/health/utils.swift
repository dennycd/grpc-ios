import Foundation

class DateHelper {

  static let shared = DateHelper()

  private lazy var formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  func normalizedDate(date: Date) -> Date {
    let normalizedStr = self.formatter.string(from: date)
    return self.formatter.date(from: normalizedStr)!
  }

  func normalizedDate(_ dateString: String) -> Date {
    return self.formatter.date(from: dateString)!
  }

  func normalizedDate(isoString: String) -> Date {
    let date = self.date(isoString: isoString)
    let normalizedStr = self.formatter.string(from: date)
    return self.formatter.date(from: normalizedStr)!
  }

  private func date(isoString: String) -> Date {
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: isoString)!
  }

}
