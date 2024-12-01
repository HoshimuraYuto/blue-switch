import Network
import SwiftUICore

/// Protocol defining the interface for managing network connections
protocol NetworkConnectionManaging {
  /// Connects to a specified network device with a message
  /// - Parameters:
  ///   - device: The network device to connect to
  ///   - message: The message to send after connection
  func connectToDevice(_ device: NetworkDevice, message: String)

  /// Sends a message through an existing connection
  /// - Parameters:
  ///   - message: The message to send
  ///   - connection: The connection to send through
  func send(message: String, to connection: NWConnection)

  /// Starts receiving data on the specified connection
  /// - Parameter connection: The connection to receive from
  func receive(on connection: NWConnection)
}

enum ConnectionError: Error {
  case sendFailed(Error)
  case receiveFailed(Error)
  case connectionFailed(Error)
}

/// Manages network connections and message handling
final class ConnectionManager: NetworkConnectionManaging {
  // MARK: - Dependencies

  @ObservedObject private var bluetoothStore = BluetoothPeripheralStore.shared

  // MARK: - Constants

  private let queue = DispatchQueue(label: "com.blueswitch.connection", qos: .userInitiated)
  private let messageEncoding: String.Encoding = .utf8

  // MARK: - NetworkConnectionManaging Implementation

  func connectToDevice(_ device: NetworkDevice, message: String) {
    guard let port = NWEndpoint.Port(rawValue: UInt16(device.port)) else {
      print("Invalid port number: \(device.port)")
      return
    }

    let connection = NWConnection(
      host: NWEndpoint.Host(device.host),
      port: port,
      using: .tcp
    )

    setupConnectionHandler(for: connection, device: device, message: message)
    connection.start(queue: queue)
  }

  func send(message: String, to connection: NWConnection) {
    guard let data = message.data(using: messageEncoding) else {
      print("Failed to encode message")
      return
    }

    connection.send(
      content: data,
      completion: .contentProcessed { error in
        if let error = error {
          self.handleSendError(error)
        } else {
          print("Message sent: \(message)")
        }
      })
  }

  func receive(on connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
      data, _, isComplete, error in
      self.handleReceivedData(
        data: data, error: error, isComplete: isComplete, connection: connection)
    }
  }

  func sendNotification(to device: NetworkDevice, title: String, message: String) {
    print("Attempting to send notification to device: \(device.name)")
    let connection = NWConnection(
      host: NWEndpoint.Host(device.host),
      port: NWEndpoint.Port(integerLiteral: UInt16(device.port)),
      using: .tcp
    )

    connection.stateUpdateHandler = { [weak self] state in
      guard let self = self else { return }
      switch state {
      case .ready:
        print("Connection ready, sending notification...")
        self.send(message: DeviceCommand.notification.rawValue, to: connection)
        self.send(message: "\(title)|\(message)", to: connection)
        print("Notification content sent to \(device.name)")
      case .failed(let error):
        print("Failed to send notification to \(device.name): \(error)")
      case .cancelled:
        print("Notification connection to \(device.name) was cancelled")
      default:
        break
      }
    }

    connection.start(queue: queue)
  }

  func sendPeripheralSync(peripherals: [BluetoothPeripheral], to device: NetworkDevice) {
    print("Attempting to sync peripherals to device: \(device.name)")

    let connection = NWConnection(
      host: NWEndpoint.Host(device.host),
      port: NWEndpoint.Port(integerLiteral: UInt16(device.port)),
      using: .tcp
    )

    connection.stateUpdateHandler = { [weak self] state in
      guard let self = self else { return }
      switch state {
      case .ready:
        print("Connection ready, sending peripherals sync...")
        // Send sync command
        self.send(message: DeviceCommand.syncPeripherals.rawValue, to: connection)

        // Encode and send peripherals data
        if let data = try? JSONEncoder().encode(peripherals),
          let jsonString = String(data: data, encoding: .utf8)
        {
          self.send(message: jsonString, to: connection)
          print("Peripherals data sent to \(device.name)")
        }
      case .failed(let error):
        print("Failed to sync peripherals to \(device.name): \(error)")
      case .cancelled:
        print("Sync connection to \(device.name) was cancelled")
      default:
        break
      }
    }

    connection.start(queue: queue)
  }

  // MARK: - Private Setup Methods

  /// Sets up the connection handler for a given device
  private func setupConnectionHandler(
    for connection: NWConnection, device: NetworkDevice, message: String
  ) {
    connection.stateUpdateHandler = { [weak self] state in
      guard let self = self else { return }
      switch state {
      case .ready:
        print("Connected to \(device.name)")
        self.send(message: message, to: connection)
        self.receive(on: connection)
      case .failed(let error):
        self.handleConnectionError(error, deviceName: device.name)
      case .cancelled:
        print("Connection to \(device.name) was cancelled")
      default:
        break
      }
    }
  }

  // MARK: - Private Data Handling Methods

  private func handleReceivedData(
    data: Data?, error: Error?, isComplete: Bool, connection: NWConnection
  ) {
    if let error = error {
      handleReceiveError(error)
      connection.cancel()
      return
    }

    if let data = data, !data.isEmpty {
      processReceivedData(data, from: connection)
    }

    if !isComplete {
      receive(on: connection)
    }
  }

  private func processReceivedData(_ data: Data, from connection: NWConnection) {
    if let message = String(data: data, encoding: messageEncoding) {
      if let command = DeviceCommand(rawValue: message) {
        handleCommand(command, connection: connection)
      } else if let lastCommand = lastReceivedCommand {
        handleCommandData(message, for: lastCommand, connection: connection)
      }
    }
  }

  private var lastReceivedCommand: DeviceCommand?

  private func handleCommand(_ command: DeviceCommand, connection: NWConnection) {
    lastReceivedCommand = command
    switch command {
    case .notification:
      // Wait for the next message which will contain notification data
      break
    case .connectAll:
      // Execute device connection
      bluetoothStore.peripherals.forEach { peripheral in
        bluetoothStore.connectPeripheral(peripheral)
      }
      // Send success response
      send(message: DeviceCommand.operationSuccess.rawValue, to: connection)

    case .unregisterAll:
      // Execute device disconnection
      bluetoothStore.peripherals.forEach { peripheral in
        bluetoothStore.unregisterFromPC(peripheral)
      }
      // Send success response
      send(message: DeviceCommand.operationSuccess.rawValue, to: connection)

    case .syncPeripherals:
      // Wait for the next message which will contain peripherals data
      break

    default:
      print("Unsupported command")
      // Send error response
      send(message: DeviceCommand.operationFailed.rawValue, to: connection)
    }
  }

  private func handleCommandData(
    _ message: String, for command: DeviceCommand, connection: NWConnection
  ) {
    switch command {
    case .notification:
      let components = message.split(separator: "|")
      if components.count == 2 {
        print("Received notification from remote device")
        NotificationManager.showNotification(
          title: String(components[0]),
          body: String(components[1])
        )
        print("Notification displayed successfully")
      } else {
        print("Invalid notification format received")
      }
    case .syncPeripherals:
      if let data = message.data(using: .utf8),
        let peripherals = try? JSONDecoder().decode([BluetoothPeripheral].self, from: data)
      {
        print("Received peripherals sync data")
        bluetoothStore.updatePeripherals(peripherals)
        print("Peripherals updated successfully")
        send(message: DeviceCommand.operationSuccess.rawValue, to: connection)
      } else {
        print("Failed to process peripherals data")
        send(message: DeviceCommand.operationFailed.rawValue, to: connection)
      }
    default:
      break
    }
    lastReceivedCommand = nil
  }

  // MARK: - Error Handling Methods

  private func handleConnectionError(_ error: Error, deviceName: String) {
    print("Failed to connect to \(deviceName): \(error)")
    // Update device information
    NetworkDeviceStore.shared.discoveredNetworkDevices.forEach { device in
      if device.name == deviceName {
        NetworkDeviceStore.shared.updateNetworkDevice(device)
        print("Updated information for \(deviceName)")
      }
    }
  }

  private func handleSendError(_ error: Error) {
    print("Send error: \(error)")
  }

  private func handleReceiveError(_ error: Error) {
    print("Receive error: \(error)")
  }
}
