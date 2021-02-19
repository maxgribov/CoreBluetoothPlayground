//
//  CentralManager.swift
//  CoreBluetoothPlayground
//
//  Created by Max Gribov on 14.02.2021.
//

import CoreBluetooth
import os

class CentralManager: NSObject {
    
    var delegate: CentralManagerDelegate?
    
    lazy var manager = CBCentralManager(delegate: self, queue: queue, options: options)
    
    private let queue = DispatchQueue.global(qos: .default)
    private let restoreIdentifier: String?
    private var options: Dictionary<String, Any> {
        
        if let  restoreIdentifier = restoreIdentifier {
            
            return [CBPeripheralManagerOptionRestoreIdentifierKey: restoreIdentifier]
            
        } else {
            
            return [:]
        }
    }
    
    private var discoveredPeripheral: CBPeripheral?
    private var transferCharacteristic: CBCharacteristic?

    init(with restoreIdentifier: String? = nil) {
        
        self.restoreIdentifier = restoreIdentifier
        super.init()
        
        manager.delegate = self
    }
    
    func send(request: TransferService.Request) {
        
        guard let transferCharacteristic = transferCharacteristic, let discoveredPeripheral = discoveredPeripheral else {
            return
        }
        
        guard let requestValue = TransferService.Request.hello.rawValue.data(using: .utf8) else {
            return
        }
        
        discoveredPeripheral.writeValue(requestValue, for: transferCharacteristic, type: .withoutResponse)
    }
    
    /*
     * We will first check if we are already connected to our counterpart
     * Otherwise, scan for peripherals - specifically for our service's 128bit CBUUID
     */
    private func retrievePeripheral() {
        
        let connectedPeripherals: [CBPeripheral] = (manager.retrieveConnectedPeripherals(withServices: [TransferService.serviceUUID]))
        
        os_log("Found connected Peripherals with transfer service: %@", connectedPeripherals)
        
        if let connectedPeripheral = connectedPeripherals.last {
            os_log("Connecting to peripheral %@", connectedPeripheral)
            self.discoveredPeripheral = connectedPeripheral
            manager.connect(connectedPeripheral, options: nil)
        } else {
            // We were not connected to our counterpart, so start scanning
            manager.scanForPeripherals(withServices: [TransferService.serviceUUID],
                                               options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }
    
    /*
    *  Call this when things either go wrong, or you're done with the connection.
    *  This cancels any subscriptions if there are any, or straight disconnects if not.
    *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
    */
   private func cleanup() {
       // Don't do anything if we're not connected
       guard let discoveredPeripheral = discoveredPeripheral,
           case .connected = discoveredPeripheral.state else { return }
       
       for service in (discoveredPeripheral.services ?? [] as [CBService]) {
           for characteristic in (service.characteristics ?? [] as [CBCharacteristic]) {
               if characteristic.uuid == TransferService.characteristicUUID && characteristic.isNotifying {
                   // It is notifying, so unsubscribe
                   discoveredPeripheral.setNotifyValue(false, for: characteristic)
               }
           }
       }
       
       // If we've gotten this far, we're connected, but we're not subscribed, so we just disconnect
       manager.cancelPeripheralConnection(discoveredPeripheral)
   }
}

extension CentralManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .poweredOn:
            os_log("CBCentralManager is powered on")
            retrievePeripheral()

            DispatchQueue.main.async {
                
                self.delegate?.didStartScanning()
            }

        case .poweredOff:
            os_log("CBCentralManager is not powered on")
            break
            
        case .resetting:
            os_log("CBCentralManager is resetting")
            break
            
        case .unauthorized:
            if #available(iOS 13.0, *) {
                switch central.authorization {
                case .denied:
                    os_log("You are not authorized to use Bluetooth")
                    break
                    
                case .restricted:
                    os_log("Bluetooth is restricted")
                    break
                    
                default:
                    os_log("Unexpected authorization")
                    break
                }
                
            } else {
                
                os_log("You are not authorized to use Bluetooth")
            }
            break
        case .unknown:
            os_log("CBCentralManager state is unknown")
            break
            
        case .unsupported:
            os_log("Bluetooth is not supported on this device")
            break
            
        @unknown default:
            os_log("A previously unknown peripheral manager state occurred")
            break
        }
    }

    /*
     *  This callback comes whenever a peripheral that is advertising the transfer serviceUUID is discovered.
     *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
     *  we start the connection process
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        // Reject if the signal strength is too low to attempt data transfer.
        // Change the minimum RSSI value depending on your app’s use case.
        guard RSSI.intValue >= -70
            else {
                os_log("Discovered perhiperal not in expected range, at %d", RSSI.intValue)
                return
        }
        
        os_log("Discovered %s at %d", String(describing: peripheral.name), RSSI.intValue)
        
        // Device is in range - have we already seen it?
        if discoveredPeripheral != peripheral {
            
            // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it.
            discoveredPeripheral = peripheral
            
            // And finally, connect to the peripheral.
            os_log("Connecting to perhiperal %@", peripheral)
            manager.connect(peripheral, options: nil)
        }
    }

    /*
     *  If the connection fails for whatever reason, we need to deal with it.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        os_log("Failed to connect to %@. %s", peripheral, String(describing: error))
        cleanup()
    }
    
    /*
     *  We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        DispatchQueue.main.async {
            
            self.delegate?.didConnected()
        }
        
        os_log("Peripheral Connected")
        
        // Stop scanning
        manager.stopScan()
        os_log("Scanning stopped")

        // Make sure we get the discovery callbacks
        peripheral.delegate = self
        
        // Search only for services that match our UUID
        peripheral.discoverServices([TransferService.serviceUUID])
    }
    
    /*
     *  Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        os_log("Perhiperal Disconnected")
        discoveredPeripheral = nil
        
        // We're disconnected, so start scanning again
        retrievePeripheral()
    }
    
}

extension CentralManager: CBPeripheralDelegate {
    // implementations of the CBPeripheralDelegate methods

    /*
     *  The peripheral letting us know when services have been invalidated.
     */
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
        for service in invalidatedServices where service.uuid == TransferService.serviceUUID {
            
            os_log("Transfer service is invalidated - rediscover services")
            peripheral.discoverServices([TransferService.serviceUUID])
        }
    }

    /*
     *  The Transfer Service was discovered
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        if let error = error {
            os_log("Error discovering services: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        // Discover the characteristic we want...
        
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        guard let peripheralServices = peripheral.services else { return }
        for service in peripheralServices {
            peripheral.discoverCharacteristics([TransferService.characteristicUUID], for: service)
        }
    }
    
    /*
     *  The Transfer characteristic was discovered.
     *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        // Deal with errors (if any).
        if let error = error {
            os_log("Error discovering characteristics: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        // Again, we loop through the array, just in case and check if it's the right one
        guard let serviceCharacteristics = service.characteristics else { return }
        for characteristic in serviceCharacteristics where characteristic.uuid == TransferService.characteristicUUID {
            // If it is, subscribe to it
            transferCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }
        
        // Once this is complete, we just need to wait for the data to come in.
    }
    
    /*
     *   This callback lets us know more data has arrived via notification on the characteristic
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        // Deal with errors (if any)
        if let error = error {
            os_log("Error discovering characteristics: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        guard let characteristicData = characteristic.value,
              let stringFromData = String(data: characteristicData, encoding: .utf8),
              let response = TransferService.Response(rawValue: stringFromData) else { return }
        
        os_log("Received %d bytes: %s response: %s", characteristicData.count, stringFromData, response.rawValue)

    }

    /*
     *  The peripheral letting us know whether our subscribe/unsubscribe happened or not
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        // Deal with errors (if any)
        if let error = error {
            os_log("Error changing notification state: %s", error.localizedDescription)
            return
        }
        
        // Exit if it's not the transfer characteristic
        guard characteristic.uuid == TransferService.characteristicUUID else { return }
        
        if characteristic.isNotifying {
            // Notification has started
            os_log("Notification began on %@", characteristic)
        } else {
            // Notification has stopped, so disconnect from the peripheral
            os_log("Notification stopped on %@. Disconnecting", characteristic)
            cleanup()
        }
    }
}

protocol CentralManagerDelegate {
    
    func didStartScanning() -> Void
    func didConnected() -> Void
}
