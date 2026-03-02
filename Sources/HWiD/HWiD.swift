import CoreBluetooth
import Foundation
import Logging

public class HWiD {
    
    private let logger: Logger
    
    private let hwidConnection: HWiDConnection
    
    private var statusContinuation: AsyncStream<HWiDStatus>.Continuation?
    
    let status: AsyncStream<HWiDStatus>
    
    let carId: AsyncStream<Data>
   
    let speed: AsyncStream<Float>
    
    
    init(logger: Logger) {
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

        self.hwidConnection = HWiDConnection(
            logger: logger,
            statusContinuation: statusContinuation!,
            carIdContinuation: carIdContinuation!,
            speedContinuation: speedContinuation!
        )
    }
}

public enum HWiDStatus {
    case scanning
    case poweredOff
    case connected
    case disconnected
    case error
}

private class HWiDConnection : NSObject {
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    
    var isConnected = false
    var discoveredDevices: [CBPeripheral] = []
    
    let advertisedServiceUUID = CBUUID(string: "AF0A6EC7-0001-000A-84A0-91559FC6F0DE")
    
    let serviceUUID = CBUUID(string: "af0a6ec7-0001-000c-84a0-91559fc6f0de")
    
    let carIdCharacteristicUUID = CBUUID(string: "AF0A6EC7-0005-000C-84A0-91559FC6F0DE")
    
    let speedCharacteristicUUID = CBUUID(string: "af0a6ec7-0006-000c-84a0-91559fc6f0de")
    
    private let logger: Logger
    
    private let statusContinuation: AsyncStream<HWiDStatus>.Continuation
    private let carIdContinuation: AsyncStream<Data>.Continuation
    private let speedContinuation: AsyncStream<Float>.Continuation
    
    init(
        logger: Logger,
        statusContinuation: AsyncStream<HWiDStatus>.Continuation,
        carIdContinuation: AsyncStream<Data>.Continuation,
        speedContinuation: AsyncStream<Float>.Continuation
        ) {
        self.logger = logger
        self.statusContinuation = statusContinuation
        self.carIdContinuation = carIdContinuation
        self.speedContinuation = speedContinuation
        
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    private func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        
        statusContinuation.yield(HWiDStatus.scanning)
        
        centralManager.scanForPeripherals(
            withServices: [advertisedServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }
    
    private func stopScanning() {
        centralManager.stopScan()
    }
    
    private func connect(to peripheral: CBPeripheral) {
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
}

extension HWiDConnection: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:  startScanning()
        case .poweredOff: statusContinuation.yield(.poweredOff)
        case .unauthorized: logger.info("Bluetooth unauthorized")
        case .unsupported: logger.info("Bluetooth not supported")
        default: logger.info("Unknown state")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        
        logger.info("Found: \(peripheral.name ?? "Unknown") | RSSI: \(RSSI)")
        
        if !discoveredDevices.contains(peripheral) {
            discoveredDevices.append(peripheral)
        }
        
        stopScanning()
        connect(to: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        logger.info("Connected to \(peripheral.name ?? "device")")
        statusContinuation.yield(.connected)
        
        isConnected = true
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        logger.info("Failed to connect: \(error?.localizedDescription ?? "unknown error")")
        statusContinuation.yield(.error)
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        statusContinuation.yield(.disconnected)
        isConnected = false
        self.peripheral = nil
    }
    
}


extension HWiDConnection: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            logger.info("Service found: \(service.uuid)")
            peripheral.discoverCharacteristics([carIdCharacteristicUUID, speedCharacteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value else { return }
        
        switch(characteristic.uuid) {
        case speedCharacteristicUUID:
            speedContinuation.yield(data.toFloat!) // TODO: Fix the bang
        case carIdCharacteristicUUID:
            carIdContinuation.yield(data)
        default:
            logger.info("Raw data: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }
    }
}


extension Data {
    var toFloat: Float? {
        guard count >= 4 else { return nil }
        return withUnsafeBytes { $0.load(as: Float.self) }
    }
}
