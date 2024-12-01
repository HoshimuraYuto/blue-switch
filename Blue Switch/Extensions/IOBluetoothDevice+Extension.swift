import IOBluetooth

/// IOBluetoothDevice Extension
/// - Provides functionality to convert Bluetooth peripherals to application-specific types
extension IOBluetoothDevice {
  /// Converts IOBluetoothDevice to BluetoothPeripheral
  /// - Returns: A new BluetoothPeripheral instance representing this device
  func toBluetoothPeripheral() -> BluetoothPeripheral {
    let name = self.name ?? "Unknown Device"
    let address = self.addressString ?? "Unknown Address"
    return BluetoothPeripheral(id: address, name: name)
  }
}
