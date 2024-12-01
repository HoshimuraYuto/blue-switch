import CoreBluetooth

/// Protocol defining the interface for Bluetooth management
protocol BluetoothManaging {
  /// Initializes and sets up the Bluetooth manager
  func setup()

  /// Current state of the Bluetooth manager
  var state: CBManagerState { get }
}

final class BluetoothManager: NSObject, BluetoothManaging {
  // MARK: - Singleton

  static let shared = BluetoothManager()

  // MARK: - Properties

  private var centralManager: CBCentralManager?

  var state: CBManagerState {
    centralManager?.state ?? .unknown
  }

  // MARK: - Initialization

  private override init() {
    super.init()
  }

  // MARK: - BluetoothManaging Implementation

  func setup() {
    centralManager = CBCentralManager(
      delegate: self,
      queue: DispatchQueue(label: "com.blueswitch.bluetooth", qos: .userInitiated)
    )
  }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    let message: String

    switch central.state {
    case .poweredOn:
      message = "Bluetooth is available"
    case .poweredOff:
      message = "Bluetooth is powered off"
    case .unauthorized:
      message = "Bluetooth use is not authorized"
    case .unsupported:
      message = "Device does not support Bluetooth"
    case .resetting:
      message = "Bluetooth is resetting"
    case .unknown:
      message = "Bluetooth state is unknown"
    @unknown default:
      message = "Unexpected Bluetooth state"
    }

    print(message)
  }
}
