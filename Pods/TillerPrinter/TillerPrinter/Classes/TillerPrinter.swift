//
//  TillerPrinter.swift
//  Pods
//
//  Created by Felix Carrard on 13/12/2016.
//
//

import UIKit

public class TillerPrinter: NSObject {
    private var maxCharactersForLine = 22
    
    public static let sharedInstance = TillerPrinter()
    
    let printManager = PrintManager.sharedInstance
    
    private override init() {}
    
    /// Render Ticket
    ///
    /// - Parameters:
    ///   - target: Target as String ("TCP:MAC_ADDRESS")
    ///   - value: Data that we want to print
    ///   - model: Model of the data we want to print
    ///   - openDrawer: Should we open the Drawer or not
    public func renderTicket(target: String, data: [String:Any], model: [[String:Any]], openDrawer: Bool = false, name: String, callback: ((Bool) -> ())?) {
        // Mix Value/Model in one Dico
        // send result dico with target to printManager
        if target.range(of: "BT") != nil  {
            maxCharactersForLine = 16
            printManager.ticketLength = target.range(of: "TM-m30") != nil ? 48 : 40
        } else {
            maxCharactersForLine = 22
            printManager.ticketLength = 48
        }
        
        let data = getDataToPrint(data: data, model: model)
        
        printManager.printTicket(target: target, data: data, openDrawer: openDrawer, callback: callback)
    }
    
    /// Open Drawer func
    ///
    /// - Parameter target: Target as String ("TCP:MAC_ADDRESS")
    public func openDrawer(target: String) {
        printManager.openDrawer(target: target)
    }
    
    /// Add the second part of the name in case of a long name
    ///
    /// - Parameter secondPart: the part that hasnt been added to the classic line
    /// - Returns: return a new line to complete the reste of the line
    func addSecondPartOfLongLine(secondPart: String) -> [String: Any] {
        var subString = ""
        if secondPart.characters.count > maxCharactersForLine {
            let charactersToRemove = secondPart.characters.count - maxCharactersForLine
            let index = secondPart.index(secondPart.endIndex, offsetBy: -charactersToRemove)
            subString = " " + secondPart.substring(to: index)
        } else {
            subString = " " + secondPart
        }
        
        let dico: [String: Any] = [
            "data": subString,
            "type": 2,
            "fontWidth": 1,
            "fontHeight": 1,
            "align": "left",
            "multiline": false,
            "background": false,
            "bold": 0,
            "margin": 4
        ]
        
        return dico
    }
    
    /// Handle the split of a long line
    ///
    /// - Parameter line: the line to split
    /// - Returns: return the secondary line
    func handleLongLine(line: inout [String]) -> String {
        let words = line[1].characters.split(separator: " ")
        var newString = String(words[0]) + " "
        var secondaryString = ""
        
        for i in 1..<words.count {
            if newString.characters.count + words[i].count < maxCharactersForLine {
                newString = newString + String(words[i]) + " "
            } else {
                secondaryString = secondaryString + String(words[i]) + " "
            }
        }
        
        line[1] = newString
        
        return secondaryString
    }
    
    /// Check if String can fit in one line or need to be split
    ///
    /// - Parameter line: the line to check
    /// - Returns: either an empty string if line doesn't need to be split, or the secondary part
    func checkLineLength(line: inout [String]) -> String {
        if line.count == 4 {
            if line[1].characters.count > maxCharactersForLine {
                return handleLongLine(line: &line)
            }
        }
        
        return ""
    }
    
    /// Handle line that needs to be duplicated (i.e Products on Ticket)
    ///
    /// - Parameters:
    ///   - finalData: Dico containing the merge from model and value until this point
    ///   - modelDico: model to print
    ///   - data: Data to print
    ///   - key: key we want to check
    /// - Returns: data + new line
    func handleMultilineModel(finalData: inout [[String: Any]], modelDico: [String: Any], data: [String: Any], key: String) {
        guard let linesData = data[key] as? [[String]] else {
            return
        }
        
        for var line in linesData {
            var newDico = modelDico
            if let type = newDico["type"] as? Int, TicketLineType(rawValue: type) == .kitchenProductText {
                newDico["data"] = line
                finalData.append(newDico)
                continue
            }
            
            let secondaryString = checkLineLength(line: &line)
            newDico["data"] = line
            finalData.append(newDico)
            
            if secondaryString != "" {
                finalData.append(addSecondPartOfLongLine(secondPart: secondaryString))
            }
        }
    }
    
    /// Handle simple line
    ///
    /// - Parameters:
    ///   - finalData: Dico containing the merge from model and value until this point
    ///   - modelDico: model to print
    ///   - data: Data to print
    ///   - key: key we want to check
    /// - Returns: data + new line
    func handleSimpleModel(finalData: inout [[String: Any]], modelDico: [String: Any], data: [String: Any], key: String) {
        var newDico = modelDico
        newDico["data"] = data[key]
        finalData.append(newDico)
    }
    
    /// Handle the type of dico according to the model
    ///
    /// - Parameters:
    ///   - finalData: Dico containing the merge from model and value until this point
    ///   - modelDico: model to print
    ///   - data: Data to print
    /// - Returns: data + new line
    func handleDico(finalData: inout [[String: Any]], modelDico: [String: Any], data: [String: Any]) {
        guard let key = modelDico["key"] as? String else {
            return
        }
        
        if let multiline = modelDico["multiline"] as? Bool, multiline == true {
            handleMultilineModel(finalData: &finalData, modelDico: modelDico, data: data, key: key)
        } else {
            handleSimpleModel(finalData: &finalData, modelDico: modelDico, data: data, key: key)
        }
    }
    
    /// Delete the line with the given key to avoid double
    ///
    /// - Parameters:
    ///   - data: Data to parse
    ///   - key: Key to detect
    private func deleteDoubleLine(for data: inout [[String:Any]], key: String) {
        var oldPosition = data.count - 1
        
        for (index, line) in data.enumerated().reversed() {
            if line["key"] as? String == key {
                if index == oldPosition - 1 {
                    data.remove(at: oldPosition)
                } else {
                    oldPosition = index
                }
            }
        }
    }
    
    /// Iterate through model to match with Data
    ///
    /// - Parameters:
    ///   - value: Data we want to print
    ///   - model: Model we want to formate data with
    /// - Returns: Merged Model and Data
    func getDataToPrint(data: [String: Any], model: [[String: Any]]) -> [[String: Any]] {
        var finalData: [[String: Any]] = [[:]]
        
        for modelDico in model {
            handleDico(finalData: &finalData, modelDico: modelDico, data: data)
        }
        
        finalData = finalData.filter({$0["data"] != nil})
        deleteDoubleLine(for: &finalData, key: "straightLine")
        deleteDoubleLine(for: &finalData, key: "emptyLine")
        
        return finalData
    }
}
