//
//  CentralViewController.swift
//  Central-Mac
//
//  Created by Max Gribov on 14.02.2021.
//

import Cocoa

class CentralViewController: NSViewController {
    
    @IBOutlet weak var status: NSTextField!
    @IBOutlet weak var sendButton: NSButton!
    
    var manager: CentralManager? {
        
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            return nil
        }
        
        return appDelegate.centralManager
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        manager?.delegate = self
        status.stringValue = "Not connected"
        sendButton.isEnabled = false
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func sendButtonDidPresed(_ sender: NSButton) {
        
        manager?.send(request: .hello)
    }
}

extension CentralViewController: CentralManagerDelegate {
    
    func didStartScanning() {
        
        status.stringValue = "Scanning..."
        
    }
    
    func didConnected() {
        
        status.stringValue = "Connected"
        sendButton.isEnabled = true
    }
}

