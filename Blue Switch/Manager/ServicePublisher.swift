import Foundation
import Network

/// Protocol defining the interface for network service publishing
protocol NetworkNetworkServicePublishable {
  /// Starts publishing the network service
  func startPublishing()

  /// Stops publishing the network service
  func stopPublishing()
}

/// Manages the publication of network services for device discovery
final class ServicePublisher: NSObject, NetworkNetworkServicePublishable {
  // MARK: - Constants

  private let serviceType = "_blueswitch._tcp."
  private let serviceDomain = "local."

  // MARK: - Dependencies

  private let connectionManager = ConnectionManager()

  // MARK: - Properties

  private var listener: NWListener?
  private var netService: NetService?
  private let queue = DispatchQueue(label: "com.blueswitch.service.publisher")

  // MARK: - NetworkNetworkServicePublishable Implementation

  func startPublishing() {
    setupListener()
  }

  func stopPublishing() {
    listener?.cancel()
    netService?.stop()
    netService = nil
  }

  // MARK: - Private Setup Methods

  /// Sets up the network listener with appropriate configuration and handlers
  private func setupListener() {
    do {
      listener = try NWListener(using: .tcp)
      configureListener()
    } catch {
      handleListenerError(error)
    }
  }

  /// Configures the listener with state and connection handlers
  private func configureListener() {
    listener?.stateUpdateHandler = { [weak self] newState in
      self?.handleListenerState(newState)
    }

    listener?.newConnectionHandler = { [weak self] newConnection in
      self?.handleNewConnection(newConnection)
    }

    listener?.start(queue: queue)
  }

  // MARK: - Private Event Handling Methods

  /// Handles updates to the listener's state
  private func handleListenerState(_ state: NWListener.State) {
    switch state {
    case .ready:
      if let port = listener?.port?.rawValue {
        print("Listener ready: Port \(port)")
        publishService(port: Int(port))
      }
    case .failed(let error):
      print("Listener error: \(error)")
    case .cancelled:
      print("Listener was cancelled")
    default:
      break
    }
  }

  /// Processes new incoming connections
  private func handleNewConnection(_ connection: NWConnection) {
    connection.start(queue: queue)
    connectionManager.receive(on: connection)
  }

  /// Handles errors that occur during listener setup
  private func handleListenerError(_ error: Error) {
    print("Failed to create listener: \(error)")
  }

  /// Publishes the service with the specified port
  private func publishService(port: Int) {
    netService = NetService(
      domain: serviceDomain,
      type: serviceType,
      name: Host.current().localizedName ?? "Unknown",
      port: Int32(port))

    netService?.delegate = self
    netService?.publish()
  }
}

// MARK: - NetServiceDelegate

extension ServicePublisher: NetServiceDelegate {
  func netServiceDidPublish(_ sender: NetService) {
    print("Service published successfully: \(sender.name)")
  }

  func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
    print("Failed to publish service: \(errorDict)")
  }
}
