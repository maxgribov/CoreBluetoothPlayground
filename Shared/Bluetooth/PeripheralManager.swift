//
//  PeripheralManager.swift
//  CoreBluetoothPlayground
//
//  Created by Max Gribov on 11.02.2021.
//

import CoreBluetooth
import os

class PeripheralManager: NSObject {
    
    private lazy var manager = CBPeripheralManager(delegate: self, queue: queue, options: options)
    
    private let queue = DispatchQueue.global(qos: .default)
    private let restoreIdentifier: String
    private var options: Dictionary<String, Any> { [CBPeripheralManagerOptionRestoreIdentifierKey: restoreIdentifier] }
    
    private var transferCharacteristic: CBMutableCharacteristic?
    private var connectedCentral: CBCentral?
    
    init(with restoreIdentifier: String) {
        
        self.restoreIdentifier = restoreIdentifier
        super.init()
        
        manager.delegate = self
    }
    
    var service: CBMutableService {
        
        let service = CBMutableService(type: TransferService.serviceUUID, primary: true)
        let characteristic = CBMutableCharacteristic(type: TransferService.characteristicUUID,
                                                     properties: [.notify, .writeWithoutResponse],
                                                     value: nil,
                                                     permissions: [.readable, .writeable])
        
        transferCharacteristic = characteristic
        service.characteristics = [characteristic]
        
        return service
    }
    
    func sendResponse(for request: TransferService.Request) -> Bool {
        
        guard let transferCharacteristic = transferCharacteristic, let connectedCentral = connectedCentral else {
            return false
        }
        
        switch request {
        case .hello:
            guard let responseValue = TransferService.Response.hello.rawValue.data(using: .utf8) else {
                return false
            }
            return manager.updateValue(responseValue, for: transferCharacteristic, onSubscribedCentrals: [connectedCentral])
        }
    }
}

extension PeripheralManager: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {

        switch peripheral.state {
        case .poweredOn:
            os_log("CBPeripheralManager is powered on")
            os_log("CBPeripheralManager added service")
            manager.removeAllServices()
            manager.add(service)
            os_log("CBPeripheralManager started adversting")
            manager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [TransferService.serviceUUID]])
            
        case .poweredOff:
            os_log("CBPeripheralManager is not powered on")
            break
            
        case .resetting:
            os_log("CBPeripheralManager is resetting")
            break
            
        case .unauthorized:
            if #available(iOS 13.0, *) {
                switch peripheral.authorization {
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
            os_log("CBPeripheralManager state is unknown")
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
     *  Catch when someone subscribes to our characteristic, then start sending them data
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        os_log("Central subscribed to characteristic")
        
        connectedCentral = central
    }
    
    /*
     *  Recognize when the central unsubscribes
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        os_log("Central unsubscribed from characteristic")
        connectedCentral = nil
    }
        
    /*
     * This callback comes in when the PeripheralManager received write to characteristics
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        
        for request in requests {
            
            guard let requestValue = request.value,
                  let stringFromData = String(data: requestValue, encoding: .utf8),
                  let request = TransferService.Request(rawValue: stringFromData) else {
                    continue
            }
            
            os_log("Received write request of %d bytes: %s request: %s", requestValue.count, stringFromData, request.rawValue)
            
            _ = sendResponse(for: request)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        
        os_log("Will restore state")
        
        guard let servicesData = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService],
              let service = servicesData.first, let characteristic = service.characteristics?.first as? CBMutableCharacteristic, let central = characteristic.subscribedCentrals?.first else {
            return
        }
        
        os_log("Restored central connection")
        connectedCentral = central
    }
}

