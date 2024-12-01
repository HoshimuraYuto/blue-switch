import Foundation
import Network
import SwiftUI

/// Protocol defining the interface for network device management operations
protocol NetworkDeviceManageable {
  /// List of registered network devices
  var networkDevices: [NetworkDevice] { get }
  /// List of discovered network devices
  var discoveredNetworkDevices: [NetworkDevice] { get }
  /// List of available network devices that can be registered
  var availableNetworkDevices: [NetworkDevice] { get }

  /// Registers a new network device
  func registerNetworkDevice(device: NetworkDevice)
  /// Removes a registered network device
  func removeNetworkDevice(device: NetworkDevice)
  /// Establishes connection to a network device
  func connectToNetworkDevice(_ device: NetworkDevice, message: String)
  /// Updates the information of a network device
  func updateNetworkDevice(_ device: NetworkDevice)
}

/// Manages the state and operations of network devices
final class NetworkDeviceStore: ObservableObject, NetworkDeviceManageable {
  // MARK: - Singleton

  static let shared = NetworkDeviceStore()

  // MARK: - Dependencies

  private let connectionManager = ConnectionManager()
  private let servicePublisher = ServicePublisher()
  private let serviceBrowser = ServiceBrowser()

  // MARK: - Properties

  @Published private(set) var networkDevices: [NetworkDevice] = []
  @Published private(set) var discoveredNetworkDevices: [NetworkDevice] = []
  @AppStorage("networkDevices") private var networkDevicesData: Data = Data()

  // MARK: - Computed Properties

  var availableNetworkDevices: [NetworkDevice] {
    discoveredNetworkDevices.filter { discovered in
      // Exclude own device from the list
      let isNotSelf = discovered.name != Host.current().localizedName
      let isNotRegistered = !networkDevices.contains(where: { $0.id == discovered.id })
      return isNotSelf && isNotRegistered
    }
  }

  // MARK: - Initialization

  private init() {
    loadNetworkDevices()
    startServices()
  }

  deinit {
    stopServices()
  }

  // MARK: - Service Management

  private func startServices() {
    servicePublisher.startPublishing()
    serviceBrowser.startBrowsing()
  }

  private func stopServices() {
    servicePublisher.stopPublishing()
    serviceBrowser.stopBrowsing()
  }

  // MARK: - Public Methods

  func registerNetworkDevice(device: NetworkDevice) {
    networkDevices.append(device)
    removeFromDiscoveredDevices(device)
    saveNetworkDevices()
  }

  func removeNetworkDevice(device: NetworkDevice) {
    networkDevices.removeAll { $0.id == device.id }
    saveNetworkDevices()
  }

  func connectToNetworkDevice(_ device: NetworkDevice, message: String) {
    connectionManager.connectToDevice(device, message: message)
  }

  func updateNetworkDevice(_ device: NetworkDevice) {
    if let index = networkDevices.firstIndex(where: { $0.id == device.id }) {
      networkDevices[index].update(with: device)
      saveNetworkDevices()
    }
  }

  /// Adds a newly discovered network device
  func addDiscoveredNetworkDevice(_ device: NetworkDevice) {
    if let index = discoveredNetworkDevices.firstIndex(where: { $0.id == device.id }) {
      discoveredNetworkDevices[index].update(with: device)
    } else {
      discoveredNetworkDevices.append(device)
    }
  }

  /// Removes a discovered network device by name
  func removeDiscoveredNetworkDevice(named name: String) {
    discoveredNetworkDevices.removeAll { $0.name == name }
  }

  /// Updates the active state of a device
  func updateDeviceIsActive(id: String, isActive: Bool) {
    if let index = networkDevices.firstIndex(where: { $0.id == id }) {
      networkDevices[index].isActive = isActive
      saveNetworkDevices()
    }
    if let index = discoveredNetworkDevices.firstIndex(where: { $0.id == id }) {
      discoveredNetworkDevices[index].isActive = isActive
    }
  }

  func sendNotification(to device: NetworkDevice) {
    // Send notification to the device
    connectionManager.sendNotification(
      to: device,
      title: "New Notification",
      message:
        "You have a new notification from \(Host.current().localizedName ?? "Unknown Device")"
    )

    // Show local notification
    NotificationManager.showNotification(
      title: "Notification Sent",
      body: "Notification sent to \(device.name)"
    )
  }

  // MARK: - Private Methods

  private func saveNetworkDevices() {
    do {
      let encoded = try JSONEncoder().encode(networkDevices)
      networkDevicesData = encoded
    } catch {
      print("Failed to save devices: \(error)")
    }
  }

  private func loadNetworkDevices() {
    do {
      networkDevices = try JSONDecoder().decode([NetworkDevice].self, from: networkDevicesData)
    } catch {
      print("Failed to load devices: \(error)")
    }
  }

  private func removeFromDiscoveredDevices(_ device: NetworkDevice) {
    discoveredNetworkDevices.removeAll { $0.id == device.id }
  }
}

/// Represents different types of device commands
enum DeviceCommand: String, Codable {
  case healthCheck = "HEALTH_CHECK"
  case unregisterAll = "UNREGISTER_ALL"
  case connectAll = "CONNECT_ALL"
  case operationSuccess = "OP_SUCCESS"
  case operationFailed = "OP_FAILED"
  case notification = "NOTIFICATION"
  case syncPeripherals = "SYNC_PERIPHERALS"
  case peripheralData = "PERIPHERAL_DATA"
}

// MARK: - Health Check Extension

extension NetworkDeviceStore {
  /// Performs a health check on the specified device
  func performHealthCheck(
    for device: NetworkDevice, completion: @escaping (HealthCheckResult) -> Void
  ) {
    device.checkHealth { result in
      DispatchQueue.main.async {
        switch result {
        case .success:
          print("Health check successful with \(device.name)")
          completion(result)
        case .failure(let error):
          print("Health check failed with \(device.name): \(error)")
          completion(result)
        case .timeout:
          print("Health check timed out with \(device.name)")
          completion(result)
        }
      }
    }
  }

  /// Executes a command on the connected device
  func executeCommand(_ command: DeviceCommand, completion: @escaping (Bool) -> Void) {
    guard let device = networkDevices.first else {
      print("No connected devices found")
      completion(false)
      return
    }

    let connection = NWConnection(
      host: NWEndpoint.Host(device.host),
      port: NWEndpoint.Port(integerLiteral: UInt16(device.port)),
      using: .tcp
    )

    connection.stateUpdateHandler = { state in
      switch state {
      case .ready:
        // Send command
        let message = command.rawValue
        self.connectionManager.send(message: message, to: connection)
      case .failed(let error):
        print("Command execution failed: \(error)")
        completion(false)
      case .cancelled:
        completion(false)
      default:
        break
      }
    }

    connection.receiveMessage { data, _, isComplete, error in
      if let error = error {
        print("Failed to receive response: \(error)")
        completion(false)
        return
      }

      if let data = data,
        let response = String(data: data, encoding: .utf8),
        let responseCommand = DeviceCommand(rawValue: response)
      {
        completion(responseCommand == .operationSuccess)
      } else {
        completion(false)
      }

      if isComplete {
        connection.cancel()
      }
    }

    connection.start(queue: .global())
  }
}

extension NetworkDeviceStore {
  func sendPeripheralSync(peripherals: [BluetoothPeripheral], to device: NetworkDevice) {
    connectionManager.sendPeripheralSync(peripherals: peripherals, to: device)
  }
}
