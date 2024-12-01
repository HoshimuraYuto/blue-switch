import Network

/// Represents the result of a health check operation
enum HealthCheckResult {
  case success
  case failure(String)
  case timeout
}

/// Protocol defining health check functionality for network devices
protocol HealthCheckable {
  /// Performs a health check on the device
  /// - Parameter completion: Closure called with the result of the health check
  func checkHealth(completion: @escaping (HealthCheckResult) -> Void)
}

extension NetworkDevice: HealthCheckable {
  func checkHealth(completion: @escaping (HealthCheckResult) -> Void) {
    let connection = NWConnection(
      host: NWEndpoint.Host(host),
      port: NWEndpoint.Port(integerLiteral: UInt16(port)),
      using: .tcp
    )

    let timeout = DispatchTime.now() + .seconds(5)

    connection.stateUpdateHandler = { state in
      switch state {
      case .ready:
        // Connection successful
        connection.cancel()
        completion(.success)
      case .failed(let error):
        connection.cancel()
        completion(.failure(error.localizedDescription))
      case .cancelled:
        break
      default:
        break
      }
    }

    connection.start(queue: .global())

    DispatchQueue.global().asyncAfter(deadline: timeout) {
      if connection.state != .cancelled {
        connection.cancel()
        completion(.timeout)
      }
    }
  }
}
