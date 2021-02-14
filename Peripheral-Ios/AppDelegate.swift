//
//  AppDelegate.swift
//  Peripheral-Ios
//
//  Created by Max Gribov on 14.02.2021.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let peripheralManager = PeripheralManager(with: TransferService.peripheralRestoreIdentifier)

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }
}

