//
//  PrinterManager.swift
//  ChristmasPhotoBooth
//
//  Created by Felix Carrard on 13/12/2017.
//  Copyright © 2017 TillerSystems. All rights reserved.
//

import UIKit

class PrinterManager: NSObject {
    static let shared = PrinterManager()
    
    var target = ""
    
    override private init() {}
}
