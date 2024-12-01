import Foundation

/// Represents a network device with its connection state and identity information
struct NetworkDevice: Identifiable, Codable {
  // MARK: - Properties

  /// Unique identifier of the device (using device name)
  let id: String

  /// Display name of the device
  var name: String

  /// Hostname or IP address of the device
  var host: String

  /// Communication port number of the device
  var port: Int

  /// Timestamp of the last device update
  var lastUpdated: Date

  /// Indicates whether the device is currently active and available
  var isActive: Bool

  // MARK: - Initialization

  /// Creates a new network device instance
  /// - Parameters:
  ///   - id: Unique identifier for the device
  ///   - name: Display name of the device
  ///   - host: Hostname or IP address
  ///   - port: Communication port number
  ///   - isActive: Initial active state of the device
  init(id: String, name: String, host: String, port: Int, isActive: Bool = true) {
    self.id = id
    self.name = name
    self.host = host
    self.port = port
    self.lastUpdated = Date()
    self.isActive = isActive
  }

  // MARK: - Public Methods

  /// Updates the device information with data from another device
  /// - Parameter device: Source device containing new information
  mutating func update(with device: NetworkDevice) {
    self.host = device.host
    self.port = device.port
    self.lastUpdated = Date()
    self.isActive = device.isActive
  }
}
