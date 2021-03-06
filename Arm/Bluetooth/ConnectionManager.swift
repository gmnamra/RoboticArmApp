//
//  Manager.swift
//  Test
//
//  Created by Džindra on 06/04/2018.
//  Copyright © 2018 STRV. All rights reserved.
//

import Foundation
import CoreBluetooth

/// Class that manages connection with  Egg device
internal class ConnectionManager: NSObject {

    static let shared = ConnectionManager()

    ////////////////////////////////////////////////////////////////
    // MARK: - Public properties

    /// Central manager is scanning for device
    public var isScanning: Bool {
        return central.isScanning
    }

    /// Central manager is ready for accepting connection
    public private(set) var isReady: Bool = false

    ////////////////////////////////////////////////////////////////
    // MARK: - Private properties

    /// Bluetooth central manager
    private let central: CBCentralManager

    /// This queue buffers all BT requests
    private let queue: DispatchQueue

    private var _roboticArm: CBPeripheral?
    private var _roboticArmDevice: RoboticArm?
    

    ////////////////////////////////////////////////////////////////
    // MARK: - Public methods

    /// Class initialization
    public override init() {
        let queue = DispatchQueue(label: "bt-queue", qos: .utility)
        
        self.central = CBCentralManager(delegate: nil, queue: queue)
        self.queue = queue
        
        super.init()
        
        central.delegate = self
    }

    /// Start scanning for advertising devices
    public func startScan() {
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])
    }

    /// Stop scanning for advertising devices
    public func stopScan() {
        central.stopScan()
    }


    /// Connect BT peripheral
    public func connect(peripheral: CBPeripheral) {
        queue.async { [weak self] in
            debugPrint("Start conn request")
            self?.central.connect(peripheral, options: nil)
        }
    }
    
    /// Disconnect BT peripheral
    public func disconnect(peripheral: CBPeripheral) {
        queue.async { [weak self] in
            debugPrint("Disconnect request")
            self?.central.cancelPeripheralConnection(peripheral)
        }
    }

    public func control(command: Command, x: Float, y: Float, z: Float, angle: Float, pump: Bool) {
        print(String(format: "command: %@, x: %.1f, y: %.1f, z: %.1f, angle: %.1f, pump: %d", command.rawValue, x, y, z, angle, pump))
        _roboticArmDevice?.control(command: command, x: x, y: y, z: z, angle: angle, pump: pump)
    }
    
    public func checkFinish() {
        delay(0.5) { [weak self] in
            if RobotState.shared.movementCompletion != nil {
                self?._roboticArmDevice?.checkFinish()
                self?.checkFinish()
            }
        }
    }
}


////////////////////////////////////////////////////////////////
// MARK: - CBCentralManagerDelegate

extension ConnectionManager: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown,.resetting:
            // TODO : temporary states, wait for next round
            break
        case .poweredOn:
            isReady = true
            startScan()
        case .unauthorized:
            isReady = false
            debugPrint("Central unauthorized")
        case .poweredOff:
            isReady = false
            debugPrint("BT powered off")
        case .unsupported:
            isReady = false
            debugPrint("BT unsupported")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        _roboticArmDevice?.didConnect()

    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        _roboticArmDevice?.didDisconnect(error: error)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {

    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        if peripheral.name == "RoboticArm" {
            _roboticArm = peripheral
            connect(peripheral: peripheral)
            stopScan()
        }


        _roboticArmDevice = RoboticArm(manager: self, peripheral: peripheral, rssi: 0, queue: queue)        
    }
}
