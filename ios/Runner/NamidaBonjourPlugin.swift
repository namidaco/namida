// by claude
import Flutter
import Foundation

/// the `namida/bonjour` channel: ios lets only the system send multicast, so sync & party advertise and browse through bonjour.
final class NamidaBonjourPlugin: NSObject, FlutterPlugin {
  private static let domain = "local."

  private let channel: FlutterMethodChannel
  private var registrations: [Int: BonjourRegistration] = [:]
  private var nextRegistrationId = 0
  private var queries: [Int: BonjourQuery] = [:]

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "namida/bonjour", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(NamidaBonjourPlugin(channel: channel), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "register":
      let type = args["type"] as? String ?? ""
      let name = args["name"] as? String ?? ""
      let port = args["port"] as? Int ?? 0
      let txt = args["txt"] as? [String: String] ?? [:]
      register(type: type, name: name, port: port, txt: txt, result: result)

    case "unregister":
      let registrationId = args["registrationId"] as? Int ?? -1
      registrations.removeValue(forKey: registrationId)?.stop()
      result(nil)

    case "browse":
      let queryId = args["queryId"] as? Int ?? -1
      let type = args["type"] as? String ?? ""
      let timeoutMS = args["timeoutMS"] as? Int ?? 3000
      browse(queryId: queryId, type: type, timeout: Double(timeoutMS) / 1000.0)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// answered once published, a denied local network access fails here instead of advertising nothing.
  private func register(type: String, name: String, port: Int, txt: [String: String], result: @escaping FlutterResult) {
    let service = NetService(domain: Self.domain, type: Self.serviceType(type), name: name, port: Int32(port))
    let txtData = txt.mapValues { Data($0.utf8) }
    let txtRecord = NetService.data(fromTXTRecord: txtData)
    service.setTXTRecord(txtRecord)
    let registrationId = nextRegistrationId
    nextRegistrationId += 1
    let registration = BonjourRegistration(service: service) { [weak self] error in
      guard let error else {
        result(registrationId)
        return
      }
      self?.registrations.removeValue(forKey: registrationId)
      result(FlutterError(code: "publish_failed", message: error, details: nil))
    }
    registrations[registrationId] = registration
    registration.publish()
  }

  private func browse(queryId: Int, type: String, timeout: TimeInterval) {
    let query = BonjourQuery(
      queryId: queryId,
      type: Self.serviceType(type),
      domain: Self.domain,
      channel: channel,
      onFinish: { [weak self] in self?.queries.removeValue(forKey: queryId) }
    )
    queries[queryId] = query
    query.start(timeout: timeout)
  }

  /// `_namida-server._tcp` -> `_namida-server._tcp.`
  private static func serviceType(_ type: String) -> String {
    return type.hasSuffix(".") ? type : type + "."
  }
}

/// one published service, reports whether publishing went through.
private final class BonjourRegistration: NSObject, NetServiceDelegate {
  /// an unanswered local network prompt leaves publishing pending without a callback.
  private static let publishTimeout: TimeInterval = 10

  private let service: NetService
  private var onPublished: ((String?) -> Void)?

  init(service: NetService, onPublished: @escaping (String?) -> Void) {
    self.service = service
    self.onPublished = onPublished
  }

  func publish() {
    service.delegate = self
    service.publish()
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.publishTimeout) { [weak self] in
      guard let self, self.onPublished != nil else { return }
      self.service.stop()
      self.complete(error: "bonjour publish timed out, local network access may be pending or denied")
    }
  }

  func stop() {
    service.stop()
  }

  func netServiceDidPublish(_ sender: NetService) {
    complete(error: nil)
  }

  func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
    let code = errorDict[NetService.errorCode]?.intValue ?? -1
    complete(error: "bonjour publish failed (\(code)), local network access may be denied")
  }

  private func complete(error: String?) {
    let onPublished = self.onPublished
    self.onPublished = nil
    onPublished?(error)
  }
}

/// browses for one service type and resolves every instance found until the timeout.
private final class BonjourQuery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
  private static let resolveTimeout: TimeInterval = 2.5

  private let queryId: Int
  private let type: String
  private let domain: String
  private let channel: FlutterMethodChannel
  private let onFinish: () -> Void

  private let browser = NetServiceBrowser()
  private var resolving: [NetService] = []
  /// a service resolves again as more of its addresses arrive, it's reported once.
  private var reportedNames = Set<String>()
  private var isDone = false

  init(queryId: Int, type: String, domain: String, channel: FlutterMethodChannel, onFinish: @escaping () -> Void) {
    self.queryId = queryId
    self.type = type
    self.domain = domain
    self.channel = channel
    self.onFinish = onFinish
  }

  func start(timeout: TimeInterval) {
    browser.delegate = self
    browser.searchForServices(ofType: type, inDomain: domain)
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
      self?.finish(error: nil)
    }
  }

  func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
    guard !isDone else { return }
    service.delegate = self
    resolving.append(service)
    service.resolve(withTimeout: Self.resolveTimeout)
  }

  func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
    let code = errorDict[NetService.errorCode]?.intValue ?? -1
    finish(error: "bonjour browse failed (\(code)), local network access may be denied")
  }

  func netServiceDidResolveAddress(_ sender: NetService) {
    guard !isDone else { return }
    let ipv4 = Self.ipv4Addresses(sender.addresses)
    guard !ipv4.isEmpty else { return }
    guard reportedNames.insert(sender.name).inserted else { return }
    sender.stop()
    var txt: [String] = []
    if let txtData = sender.txtRecordData() {
      for (key, value) in NetService.dictionary(fromTXTRecord: txtData) {
        txt.append("\(key)=\(String(decoding: value, as: UTF8.self))")
      }
    }
    channel.invokeMethod("onServiceFound", arguments: [
      "queryId": queryId,
      "name": sender.name,
      "host": sender.hostName ?? "",
      "port": sender.port,
      "ipv4": ipv4,
      "txt": txt,
    ])
  }

  private func finish(error: String?) {
    guard !isDone else { return }
    isDone = true
    browser.stop()
    for service in resolving {
      service.stop()
    }
    resolving.removeAll()
    var arguments: [String: Any] = ["queryId": queryId]
    if let error {
      arguments["error"] = error
    }
    channel.invokeMethod("onQueryDone", arguments: arguments)
    onFinish()
  }

  private static func ipv4Addresses(_ addresses: [Data]?) -> [String] {
    var result: [String] = []
    for data in addresses ?? [] {
      data.withUnsafeBytes { raw in
        guard raw.count >= MemoryLayout<sockaddr_in>.size else { return }
        let family = raw.loadUnaligned(as: sockaddr.self).sa_family
        guard family == sa_family_t(AF_INET) else { return }
        var address = raw.loadUnaligned(as: sockaddr_in.self).sin_addr
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else { return }
        result.append(String(cString: buffer))
      }
    }
    return result
  }
}
