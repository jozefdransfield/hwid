import CoreBluetooth
import Foundation
import Logging

public class HWiD {
    
    private let logger: Logger
    
    private let hwidConnection: HWiDConnection
    
    private var statusContinuation: AsyncStream<HWiDStatus>.Continuation?
    
    public let status: AsyncStream<HWiDStatus>
    
    public let carId: AsyncStream<Data>
    
    public let speed: AsyncStream<Float>
    
    public init(
        logger: Logger,
        connectionFactory: ( (Logger, AsyncStream<HWiDStatus>.Continuation, AsyncStream<Data>.Continuation, AsyncStream<Float>.Continuation) -> HWiDConnection)? = nil) {
            self.logger = logger
            
            var statusContinuation: AsyncStream<HWiDStatus>.Continuation?
            var carIdContinuation: AsyncStream<Data>.Continuation?
            var speedContinuation: AsyncStream<Float>.Continuation?
            
            self.status = AsyncStream { continuation in
                statusContinuation = continuation
            }
            
            self.carId = AsyncStream { continuation in
                carIdContinuation = continuation
            }
            
            self.speed = AsyncStream { continuation in
                speedContinuation = continuation
            }
            
            if let connectionFactory = connectionFactory {
                self.hwidConnection = connectionFactory(logger, statusContinuation!, carIdContinuation!, speedContinuation!)
            } else {
                self.hwidConnection = BluetoothHWiDConnection(
                    logger: logger,
                    statusContinuation: statusContinuation!,
                    carIdContinuation: carIdContinuation!,
                    speedContinuation: speedContinuation!
                )
            }
        }
    
    public func scan() {
        self.hwidConnection.startScanning()
    }
}

extension Data {
    var toFloat: Float? {
        guard count >= 4 else { return nil }
        return withUnsafeBytes { $0.load(as: Float.self) }
    }
}
