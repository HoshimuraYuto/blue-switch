import Foundation
import IOBluetooth
import SwiftUI

/// Protocol defining the interface for Bluetooth peripheral management operations
protocol BluetoothPeripheralManageable {
  /// Fetches and updates the list of connected peripherals
  func fetchConnectedPeripherals()

  /// Adds a new peripheral to the managed list
  func addPeripheral(_ peripheral: BluetoothPeripheral)

  /// Initiates connection to a peripheral
  func connectPeripheral(_ peripheral: BluetoothPeripheral)

  /// Disconnects from a peripheral
  func disconnectPeripheral(_ peripheral: BluetoothPeripheral)
}

/// Manages the state and operations of Bluetooth peripherals
final class BluetoothPeripheralStore: ObservableObject, BluetoothPeripheralManageable {
  // MARK: - Singleton

  static let shared = BluetoothPeripheralStore()

  // MARK: - Constants

  private enum Constants {
    static let queueLabel = "com.blueswitch.bluetooth"
    static let invalidRSSI = 127
  }

  // MARK: - Dependencies

  private let bluetoothQueue = DispatchQueue(label: Constants.queueLabel, qos: .userInitiated)

  // MARK: - Properties

  @AppStorage("peripherals") private var peripheralsData: Data = Data()

  @Published private(set) var peripherals: [BluetoothPeripheral] = [] {
    didSet {
      savePeripherals()
    }
  }

  @Published private(set) var discoveredPeripherals: [BluetoothPeripheral] = []

  // MARK: - Computed Properties

  var availablePeripherals: [BluetoothPeripheral] {
    discoveredPeripherals.filter { discovered in
      !peripherals.contains(where: { $0.id == discovered.id })
    }
  }

  var isAllDevicesConnected: Bool {
    guard !peripherals.isEmpty else { return false }
    return peripherals.allSatisfy { peripheral in
      guard let btDevice = IOBluetoothDevice(addressString: peripheral.id) else { return false }
      return btDevice.isConnected()
    }
  }

  // MARK: - Initialization

  private init() {
    loadPeripherals()
    fetchConnectedPeripherals()
  }

  // MARK: - Public Methods

  /// Adds a peripheral to the managed list in connected state
  /// - Parameter peripheral: The peripheral to add
  func addPeripheral(_ peripheral: BluetoothPeripheral) {
    guard validateBluetoothState() else { return }
    guard validateDeviceExists(peripheral) else { return }

    var newPeripheral = peripheral
    peripherals.append(newPeripheral)
  }

  /// Removes peripheral information from the system while maintaining it in the list
  /// - Parameter peripheral: The peripheral to unregister
  func unregisterFromPC(_ peripheral: BluetoothPeripheral) {
    guard validateBluetoothState() else { return }
    guard let btDevice = getBluetoothDevice(for: peripheral) else { return }

    if !btDevice.isConnected() {
      print("Device is already disconnected: \(peripheral.name)")
      return
    }

    if btDevice.responds(to: Selector(("remove"))) {
      btDevice.perform(Selector(("remove")))
      print("Device information removed: \(peripheral.name)")
    } else {
      print("Failed to remove device information: \(peripheral.name)")
    }
  }

  /// Completely remove device from list
  func removeFromList(_ peripheral: BluetoothPeripheral) {
    guard let index = peripherals.firstIndex(where: { $0.id == peripheral.id }) else {
      print("\(peripheral.name) does not exist in the list")
      return
    }

    //    if let btDevice = IOBluetoothDevice(addressString: peripheral.id),
    //      btDevice.isConnected()
    //    {
    //      print("\(peripheral.name) is connected. Please disconnect before removing")
    //      return
    //    }

    peripherals.removeAll { $0.id == peripheral.id }
    print("\(peripheral.name) has been removed from the list")
  }

  func connectPeripheral(_ peripheral: BluetoothPeripheral) {
    bluetoothQueue.async { [weak self] in
      guard let self = self else { return }

      // Get device and basic checks
      guard let btDevice = IOBluetoothDevice(addressString: peripheral.id) else {
        print("\(peripheral.name) not found")
        return
      }

      // Check Bluetooth system status
      guard IOBluetoothHostController.default().powerState != kBluetoothHCIPowerStateOFF else {
        print("Bluetooth is turned off")
        return
      }

      // Check if device is in range using RSSI value
      let rssi = btDevice.rssi()
      if rssi == Constants.invalidRSSI {  // 127 indicates invalid RSSI value
        print("\(peripheral.name) is out of range or not responding")
        return
      }

      guard let devicePair = IOBluetoothDevicePair(device: btDevice) else {
        print("Failed to initialize pairing for \(peripheral.name)")
        return
      }

      devicePair.delegate = self
      let pairResult = devicePair.start()

      if pairResult == kIOReturnSuccess {
        // Check actual connection status
        let connectResult = btDevice.openConnection()
        if connectResult == kIOReturnSuccess && btDevice.isConnected() {
          DispatchQueue.main.async {
            guard let index = self.peripherals.firstIndex(where: { $0.id == peripheral.id }) else {
              return
            }
            var updatedPeripheral = peripheral
            self.peripherals[index] = updatedPeripheral
            print("Connected to \(peripheral.name)")
          }
        } else {
          print("Failed to connect to \(peripheral.name). Error code: \(connectResult)")
        }
      } else {
        print("Failed to start pairing with \(peripheral.name). Error code: \(pairResult)")
      }
    }
  }

  /// Disconnect device
  func disconnectPeripheral(_ peripheral: BluetoothPeripheral) {
    guard IOBluetoothHostController.default().powerState != kBluetoothHCIPowerStateOFF else {
      print("Bluetooth is turned off")
      return
    }

    guard let btDevice = IOBluetoothDevice(addressString: peripheral.id) else {
      print("\(peripheral.name) not found")
      return
    }

    if !btDevice.isConnected() {
      print("\(peripheral.name) is already disconnected")
      return
    }

    let result = btDevice.closeConnection()
    if result == kIOReturnSuccess {
      print("Disconnected from \(peripheral.name)")
    } else {
      print("Failed to disconnect from \(peripheral.name). Error code: \(result)")
    }
  }

  func fetchConnectedPeripherals() {
    bluetoothQueue.async { [weak self] in
      guard let self = self else { return }

      guard IOBluetoothHostController.default().powerState != kBluetoothHCIPowerStateOFF else {
        print("Bluetooth is turned off")
        return
      }

      guard let pairedPeripherals = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
        print("No paired peripherals found")
        return
      }

      if pairedPeripherals.isEmpty {
        DispatchQueue.main.async {
          self.discoveredPeripherals = []
        }
        print("No available peripherals found")
        return
      }

      let newAvailablePeripherals =
        pairedPeripherals
        .map { device in
          BluetoothPeripheral(
            id: device.addressString ?? "Unknown",
            name: device.name ?? "Unknown Device"
          )
        }
        .filter { peripheral in !self.peripherals.contains(where: { $0.id == peripheral.id }) }

      DispatchQueue.main.async {
        self.discoveredPeripherals = newAvailablePeripherals
        if newAvailablePeripherals.isEmpty {
          print("No new available peripherals found")
        }
      }
    }
  }

  /// Updates the peripheral list with new data from sync
  /// - Parameter newPeripherals: Array of peripherals to update with
  func updatePeripherals(_ newPeripherals: [BluetoothPeripheral]) {
    print("Debug: Starting peripheral update with \(newPeripherals.count) devices")

    if !Thread.isMainThread {
      DispatchQueue.main.async { [weak self] in
        self?.updatePeripherals(newPeripherals)
      }
      return
    }

    print("Debug: Current peripherals count: \(peripherals.count)")

    peripherals = newPeripherals
    print("Debug: After update peripherals count: \(peripherals.count)")
    print("Debug: Updated peripherals: \(peripherals.map { $0.name })")

    savePeripherals()
  }

  // MARK: - Private Methods

  private func savePeripherals() {
    do {
      let encoded = try JSONEncoder().encode(peripherals)
      peripheralsData = encoded
    } catch {
      print("Failed to save peripherals: \(error)")
    }
  }

  private func loadPeripherals() {
    do {
      peripherals = try JSONDecoder().decode([BluetoothPeripheral].self, from: peripheralsData)
    } catch {
      print("Failed to load peripherals: \(error)")
    }
  }

  // MARK: - Helper Methods

  private func handleConnectionResult(result: IOReturn, peripheralName: String) {
    if result == kIOReturnSuccess {
      print("\(peripheralName) has been connected")
    } else {
      print("Failed to connect to \(peripheralName). Error code: \(result)")
    }
  }

  private func handleDisconnectionResult(result: IOReturn, peripheralName: String) {
    if result == kIOReturnSuccess {
      print("Disconnected from \(peripheralName)")
    } else {
      print("Failed to disconnect from \(peripheralName)")
    }
  }

  private func validateBluetoothState() -> Bool {
    let powerState = IOBluetoothHostController.default().powerState
    guard powerState != kBluetoothHCIPowerStateOFF else {
      print("Bluetooth is turned off")
      return false
    }
    return true
  }

  private func validateDeviceExists(_ peripheral: BluetoothPeripheral) -> Bool {
    guard IOBluetoothDevice(addressString: peripheral.id) != nil else {
      print("Device not found: \(peripheral.name)")
      return false
    }
    return true
  }

  private func getBluetoothDevice(for peripheral: BluetoothPeripheral) -> IOBluetoothDevice? {
    guard let device = IOBluetoothDevice(addressString: peripheral.id) else {
      print("Device not found: \(peripheral.name)")
      return nil
    }
    return device
  }
}

extension BluetoothPeripheralStore {
  /// Checks the actual connection status of all registered peripherals using IOBluetoothDevice
  /// - Returns: ConnectionStatus indicating the current state
  enum ConnectionStatus {
    case allConnected
    case allDisconnected
    case partial
  }

  func checkActualConnectionStatus() -> ConnectionStatus {
    guard !peripherals.isEmpty else { return .allDisconnected }

    var connectedCount = 0
    var totalCount = 0

    for peripheral in peripherals {
      if let btDevice = IOBluetoothDevice(addressString: peripheral.id) {
        totalCount += 1
        if btDevice.isConnected() {
          connectedCount += 1
        }
      }
    }

    if connectedCount == totalCount && totalCount > 0 {
      return .allConnected
    } else if connectedCount == 0 {
      return .allDisconnected
    } else {
      return .partial
    }
  }
}
