import CoreBluetooth
import Foundation
import Logging

class HWiD: NSObject{
    
    private let logger: Logger
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    
    var isConnected = false
    var discoveredDevices: [CBPeripheral] = []
    
    let advertisedServiceUUID = CBUUID(string: "AF0A6EC7-0001-000A-84A0-91559FC6F0DE")
    
    let serviceUUID = CBUUID(string: "af0a6ec7-0001-000c-84a0-91559fc6f0de")
    
    let carIdCharacteristicUUID = CBUUID(string: "AF0A6EC7-0005-000C-84A0-91559FC6F0DE")
    
    let speedCharacteristicUUID = CBUUID(string: "af0a6ec7-0006-000c-84a0-91559fc6f0de")
    
    private var speedContinuation: AsyncStream<Float>.Continuation?
    
    lazy var speed: AsyncStream<Float> = {
        AsyncStream { continuation in
            self.speedContinuation = continuation
        }
    }()
    
    private var carIdContinuation: AsyncStream<Data>.Continuation?
    
    lazy var carId: AsyncStream<Data> = {
        AsyncStream { continuation in
            self.carIdContinuation = continuation
        }
    }()
    
    init(logger: Logger) {
        self.logger = logger
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    private func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        
        logger.info("Scanning for peripherals...")
        
        centralManager.scanForPeripherals(
            withServices: [advertisedServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }
    
    private func stopScanning() {
        centralManager.stopScan()
        logger.info("Stopped scanning")
    }
    
    private func connect(to peripheral: CBPeripheral) {
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    private func updateSpeed(value: Float) {
        speedContinuation?.yield(value)
    }
    
    private func updateCarId(value: Data) {
        carIdContinuation?.yield(value)
    }
}

extension HWiD: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:  logger.info("Bluetooth is ON"); startScanning()
        case .poweredOff: logger.info("Bluetooth is OFF")
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
        isConnected = true
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        logger.info("Failed to connect: \(error?.localizedDescription ?? "unknown error")")
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        logger.info("Disconnected")
        isConnected = false
        self.peripheral = nil
    }
    
}


extension HWiD: CBPeripheralDelegate {
    
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
            self.updateSpeed(value: data.toFloat!) // TODO: Fix the bang
        case carIdCharacteristicUUID:
            self.updateCarId(value: data)
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
