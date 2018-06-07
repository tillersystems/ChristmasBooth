//
//  PrinterManager.swift
//  Pods
//
//  Created by Felix Carrard on 13/12/2016.
//
//

import UIKit

public protocol DiscoveryManagerDelegate: class {
    func didDiscoverDevice(deviceInfo: Epos2DeviceInfo)
}

public class DiscoveryManager: NSObject, Epos2DiscoveryDelegate {

    public weak var delegate: DiscoveryManagerDelegate?
    private var filterOption = Epos2FilterOption()

    public func discoverDevices() {
        filterOption.deviceType = EPOS2_TYPE_PRINTER.rawValue
        
        Epos2Discovery.stop()
        let result = Epos2Discovery.start(filterOption, delegate: self)
        if result != EPOS2_SUCCESS.rawValue {
            print("error")
        }
    }
    
    public func onDiscovery(_ deviceInfo: Epos2DeviceInfo!) {
        guard let delegate = delegate else {
            return
        }
        
        delegate.didDiscoverDevice(deviceInfo: deviceInfo)
    }
}
