// by claude
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif
import Foundation

/// the `namida/bonjour` channel: sync & party advertise and browse through the system's bonjour, for both the ios and macos runners.
/// ios lets only the system send multicast, and macos's mDNSResponder already holds port 5353.
final class NamidaBonjourPlugin: NSObject, FlutterPlugin {
  private static let domain = "local."

  private let channel: FlutterMethodChannel
  private var registrations: [Int: BonjourRegistration] = [:]
  private var queries: [Int: BonjourQuery] = [:]

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: "namida/bonjour", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(NamidaBonjourPlugin(channel: channel), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "register":
      let registrationId = args["registrationId"] as? Int ?? -1
      let type = args["type"] as? String ?? ""
      let name = args["name"] as? String ?? ""
      let port = args["port"] as? Int ?? 0
      let txt = args["txt"] as? [String: String] ?? [:]
      register(registrationId: registrationId, type: type, name: name, port: port, txt: txt)
      result(nil)

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

  /// publishing can wait on the local network prompt for as long as the user takes, so dart gets each state as it comes.
  private func register(registrationId: Int, type: String, name: String, port: Int, txt: [String: String]) {
    let service = NetService(domain: Self.domain, type: Self.serviceType(type), name: name, port: Int32(port))
    let txtData = txt.mapValues { Data($0.utf8) }
    let txtRecord = NetService.data(fromTXTRecord: txtData)
    service.setTXTRecord(txtRecord)
    let registration = BonjourRegistration(service: service) { [weak self] error in
      var arguments: [String: Any] = ["registrationId": registrationId]
      if let error {
        arguments["error"] = error
      }
      self?.channel.invokeMethod("onRegistrationUpdate", arguments: arguments)
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

/// one published service, reports each publishing state. `nil` = published.
private final class BonjourRegistration: NSObject, NetServiceDelegate {
  /// an unanswered local network prompt or a denied access leaves publishing pending without a callback.
  private static let slowPublishDelay: TimeInterval = 10

  private let service: NetService
  private let onUpdate: (String?) -> Void
  private var isSettled = false

  init(service: NetService, onUpdate: @escaping (String?) -> Void) {
    self.service = service
    self.onUpdate = onUpdate
  }

  func publish() {
    service.delegate = self
    service.publish()
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.slowPublishDelay) { [weak self] in
      guard let self, !self.isSettled else { return }
      self.onUpdate("bonjour publish is still waiting, local network access may be pending or denied")
    }
  }

  /// the delegate isn't retained by the service, it's cleared before this registration is dropped.
  func stop() {
    service.delegate = nil
    service.stop()
  }

  func netServiceDidPublish(_ sender: NetService) {
    isSettled = true
    onUpdate(nil)
  }

  func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
    isSettled = true
    let code = errorDict[NetService.errorCode]?.intValue ?? -1
    onUpdate("bonjour publish failed (\(code)), local network access may be denied")
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

  /// delegates aren't retained by the browser & services, they're cleared before this query is dropped.
  private func finish(error: String?) {
    guard !isDone else { return }
    isDone = true
    browser.delegate = nil
    browser.stop()
    for service in resolving {
      service.delegate = nil
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
