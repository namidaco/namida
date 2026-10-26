// by claude
import Foundation

/// links & text the share extension received, carried to the app in one `namida://share` url.
enum NamidaShareUrl {
  private static let scheme = "namida"
  private static let host = "share"
  private static let textQueryName = "text"

  static func build(_ texts: [String]) -> URL? {
    if texts.isEmpty { return nil }
    var components = URLComponents()
    components.scheme = scheme
    components.host = host
    components.queryItems = texts.map { URLQueryItem(name: textQueryName, value: $0) }
    return components.url
  }

  /// nil when [url] isn't a share url.
  static func parse(_ url: URL) -> [String]? {
    guard url.scheme == scheme, url.host == host else { return nil }
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let queryItems = components?.queryItems ?? []
    return queryItems.filter { $0.name == textQueryName }.compactMap { $0.value }
  }
}
