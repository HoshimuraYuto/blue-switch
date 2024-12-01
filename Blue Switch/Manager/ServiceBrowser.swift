import Foundation
import Network

/// Protocol defining the interface for service discovery
protocol ServiceBrowsing {
  /// Starts browsing for available network services
  func startBrowsing()

  /// Stops browsing and clears discovered services
  func stopBrowsing()
}

/// Manages network service discovery and resolution
final class ServiceBrowser: NSObject, ServiceBrowsing {
  // MARK: - Constants

  private let serviceType = "_blueswitch._tcp."
  private let serviceDomain = "local."
  private let timeout: TimeInterval = 5.0

  // MARK: - Properties

  private var serviceBrowser: NetServiceBrowser?
  private var services: [NetService] = []

  // MARK: - ServiceBrowsing Implementation

  func startBrowsing() {
    serviceBrowser = NetServiceBrowser()
    serviceBrowser?.delegate = self
    serviceBrowser?.searchForServices(ofType: serviceType, inDomain: serviceDomain)
  }

  func stopBrowsing() {
    serviceBrowser?.stop()
    services.removeAll()
  }
}

// MARK: - NetServiceBrowserDelegate

extension ServiceBrowser: NetServiceBrowserDelegate {
  func netServiceBrowser(
    _ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool
  ) {
    print("Service discovered: \(service.name)")
    services.append(service)
    service.delegate = self
    service.resolve(withTimeout: timeout)
  }

  func netServiceBrowser(
    _ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool
  ) {
    print("Service removed: \(service.name)")
    services.removeAll { $0 == service }
    DispatchQueue.main.async {
      NetworkDeviceStore.shared.updateDeviceIsActive(id: service.name, isActive: false)
    }
  }
}

// MARK: - NetServiceDelegate

extension ServiceBrowser: NetServiceDelegate {
  /// Handles successful resolution of a network service address
  func netServiceDidResolveAddress(_ sender: NetService) {
    guard let addresses = sender.addresses else { return }

    for addressData in addresses {
      if let host = getHost(from: addressData), sender.port != 0 {
        let device = NetworkDevice(
          id: sender.name,
          name: sender.name,
          host: host,
          port: sender.port,
          isActive: true
        )

        DispatchQueue.main.async {
          NetworkDeviceStore.shared.addDiscoveredNetworkDevice(device)
          NetworkDeviceStore.shared.updateNetworkDevice(device)
          print("Device information updated: \(sender.name)")
        }
        break
      }
    }
  }

  /// Extracts host information from network address data
  /// - Parameter addressData: Raw address data
  /// - Returns: Formatted host string if successful, nil otherwise
  private func getHost(from addressData: Data) -> String? {
    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

    let result = addressData.withUnsafeBytes { pointer -> Int32 in
      let sockaddr = pointer.bindMemory(to: sockaddr.self).baseAddress!
      return getnameinfo(
        sockaddr,
        socklen_t(addressData.count),
        &hostname,
        socklen_t(hostname.count),
        nil,
        0,
        NI_NUMERICHOST
      )
    }

    return result == 0 ? String(cString: hostname) : nil
  }
}
