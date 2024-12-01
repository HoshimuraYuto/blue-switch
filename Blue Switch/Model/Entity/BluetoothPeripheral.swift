import Foundation
import IOBluetooth

/// Represents a Bluetooth peripheral device with its connection state and identity information
struct BluetoothPeripheral: Identifiable, Codable {
  // MARK: - Properties

  /// Unique identifier (MAC address) of the Bluetooth device
  let id: String

  /// Display name of the Bluetooth device
  var name: String

  /// Indicates whether the device is currently connected
  var isConnected: Bool {
    if let btDevice = IOBluetoothDevice(addressString: id) {
      return btDevice.isConnected()
    }
    return false
  }
}
