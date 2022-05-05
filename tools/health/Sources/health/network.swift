import Combine
import Foundation

// https://ampersandsoftworks.com/posts/bearer-authentication-nsurlsession/

private let VERBOSE = true
private func debug(_ content: String) {
  if VERBOSE { print(content) }
}

class NetworkClient {

  typealias FetchCallback = ([Issue]) -> Void
  typealias FetchPRCallback = (PullRequest) -> Void
  typealias FetchPRSCallback = ([PullRequest]) -> Void

  typealias FetchIssueFilter = (Issue) -> Bool

  enum FetchError: Error {
    case generic(String)
  }

  static let shared = NetworkClient()

  var lang: String = ""
  var bags = Set<AnyCancellable>()
  let authValue = "token \(GITHUB_TOKEN)"

  var nextPage = 1
  var totalPage = 1

  func fetchIssues(
    lang: String,
    onDone: @escaping FetchCallback
  ) {

    self.lang = lang
    var results = [Issue]()

    func handler(_ issues: [Issue]) {
      results.append(contentsOf: filterIssues(issues, filter: nil, fetchPR: false))

      if self.nextPage <= self.totalPage {
        self.fetchIssuePage(onDone: handler)
      } else {
        debug("total \(results.count) issues fetched")
        onDone(results)
      }
    }

    resetPagination()
    fetchIssuePage(onDone: handler)
  }

  func fetchPRs(
    lang: String,
    filter: FetchIssueFilter? = nil,
    onDone: @escaping FetchPRSCallback
  ) {

    self.lang = lang
    var results = [Issue]()

    func handler(_ issues: [Issue]) {
      results.append(contentsOf: filterIssues(issues, filter: filter, fetchPR: true))

      if self.nextPage <= self.totalPage {
        self.fetchIssuePage(onDone: handler)
      } else {
        debug("total \(results.count) PRs fetched")

        let prs = results.map { $0.number }
        fetchPullRequests(prs, onDone)
      }
    }

    resetPagination()
    fetchIssuePage(onDone: handler)
  }

  // https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration?language=objc
  private func defaultSessionConfig() -> URLSessionConfiguration {
    let config = URLSessionConfiguration.default
    config.httpAdditionalHeaders = [
      "Authorization": authValue
    ]
    return config
  }

  private func fetchIssuePage(onDone: @escaping FetchCallback) {

    debug("fetching page \(nextPage) / \(totalPage)")

    let request = urlRequest(nextPage)
    // debug("sending request \(request.url!.absoluteString)")

    // actual request
    let session = URLSession(configuration: defaultSessionConfig())

    // https://developer.apple.com/documentation/foundation/urlsession/processing_url_session_data_task_results_with_combine
    session
      .dataTaskPublisher(for: request)
      .tryMap { (data, response) -> Data in
        guard let res = response as? HTTPURLResponse,
          res.statusCode == 200
        else {
          // throw FetchError.generic("error fetching with response \(response)")
          debug("error fetching with response \(response)")
          return data
        }

        self.updatePagination(res.allHeaderFields["Link"] as! String)
        return data
      }
      .decode(type: [Issue].self, decoder: JSONDecoder())
      .sink(receiveCompletion: { completion in
        switch completion {
        case let .failure(reason):
          debug("fetch failed with error \(reason)")
        case .finished:
          // debug("fetch success.")
          return
        }
      }) { issues in
        debug("received \(issues.count) issues")
        onDone(issues)
      }
      .store(in: &bags)

  }

  // <https://api.github.com/repositories/27729880/issues?filter=all&state=all&per_page=100&page=2>; rel="next",
  // <https://api.github.com/repositories/27729880/issues?filter=all&state=all&per_page=100&page=294>; rel="last"
  private func updatePagination(_ linkInfo: String) {
    // debug("link info is \(linkInfo)")

    let parts = linkInfo.split(separator: ",").map { String($0) }

    func getPage(_ input: String) -> Int {
      // next page info
      let nextPageInfo = input.split(separator: ";").map {
        String($0).trimmingCharacters(in: .whitespacesAndNewlines)
      }
      let urlStr = nextPageInfo[0].filter { !"<>".contains($0) }
      let components = URLComponents(string: urlStr)!

      var page: Int?
      for item in components.queryItems ?? [] {
        if item.name == "page" {
          page = Int(item.value!)
          break
        }
      }
      return page!
    }

    var nextPage: Int?
    var totalPage: Int?
    for part in parts {
      if part.contains("rel=\"next\"") { nextPage = getPage(part) }
      if part.contains("rel=\"last\"") { totalPage = getPage(part) }
    }

    self.totalPage = totalPage ?? self.totalPage

    if nextPage != nil {
      self.nextPage = nextPage!
      // debug("nextPage: \(nextPage!), totalPage: \(totalPage!)")
    } else {
      // debug("last page fetched!!")
      self.nextPage = self.totalPage + 1
    }

  }

  func resetPagination() {
    nextPage = 1
    totalPage = 1
  }

  private func urlRequest(_ page: Int) -> URLRequest {
    let lables = LangLabel[self.lang]!
    let url = URL(
      string:
        "https://api.github.com/repos/grpc/grpc/issues?filter=all&state=all&per_page=100&page=\(page)&labels=\(lables)"
    )!
    var request = URLRequest(url: url)
    applyRequestHeaderContent(&request)

    // TODO: remove
    request.cachePolicy = .returnCacheDataElseLoad
    return request
  }

  private func applyRequestHeaderContent(_ request: inout URLRequest) {
    request.setValue(authValue, forHTTPHeaderField: "Authentication")
    request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Content-Type")
  }

  private func filterIssues(_ issues: [Issue], filter: FetchIssueFilter?, fetchPR: Bool = false)
    -> [Issue]
  {
    return issues.filter {
      let isPR = $0.pull_request != nil
      var pass = fetchPR == isPR
      if let filter = filter {
        pass = pass && filter($0)
      }
      return pass
    }
  }

  private func fetchPullRequests(_ prs: [Int], _ onDone: @escaping FetchPRSCallback) {
    let n = prs.count
    debug("fetching \(n) PRs...".yellow)

    var prs = prs
    var results = [PullRequest]()

    func checkDoneAndReturn() {
      if prs.isEmpty {
        debug("done fetching all \(results.count) PRs".yellow)
        onDone(results)
        return
      }

      let pr = prs.removeLast()
      debug("fetching \(results.count + 1)/\(n) PR")
      fetchPullRequest(pr) {
        results.append($0)
        checkDoneAndReturn()
      }
    }

    checkDoneAndReturn()

  }

  private func fetchPullRequest(_ number: Int, _ onDone: @escaping FetchPRCallback) {

    let url = URL(string: "https://api.github.com/repos/grpc/grpc/pulls/\(number)")!
    var request = URLRequest(url: url)
    applyRequestHeaderContent(&request)

    let session = URLSession(configuration: defaultSessionConfig())

    session.dataTaskPublisher(for: request)
      .tryMap { (data, response) -> Data in
        guard let httpRes = response as? HTTPURLResponse,
          httpRes.statusCode == 200
        else {
          throw URLError(.badServerResponse)
        }
        return data
      }
      .decode(type: PullRequest.self, decoder: JSONDecoder())
      .sink(receiveCompletion: { completion in
        switch completion {
        case let .failure(reason):
          debug("fetch failed with error \(reason)")
        case .finished:
          return
        }
      }) {
        //debug("\($0)")
        onDone($0)
      }
      .store(in: &bags)

  }

}
