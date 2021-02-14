//
//  TransferService.swift
//  CoreBluetoothPlayground
//
//  Created by Max Gribov on 14.02.2021.
//

import CoreBluetooth

struct TransferService {
    
    static let serviceUUID = CBUUID(string: "E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
    static let characteristicUUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D4")
    
    static let peripheralRestoreIdentifier = "33458d15-49b3-4188-85fb-50e36aae5cc4"
    
    static let adversting: [String : Any] = [CBAdvertisementDataLocalNameKey: "airkeyfc61" , CBAdvertisementDataServiceUUIDsKey: [serviceUUID]]
}

extension TransferService {
    
    enum Request: String {
        
        case hello
    }
    
    enum Response: String {
        
        case hello
    }
}
