
//
//  PrintManager.swift
//  Pods
//
//  Created by Felix Carrard on 13/12/2016.
//
//

import UIKit

public enum TicketLineType: Int {
    case emptyLine = 0
    case straightLine = 1
    case simpleText = 2
    case multipleText = 3
    case image = 4
    case kitchenProductText = 5
}

class PrintManager: NSObject, Epos2PtrReceiveDelegate {
    
    public static let sharedInstance = PrintManager()
    public var ticketLength = 48
    
    var printer: Epos2Printer?
    let lockQueue = DispatchQueue(label: "com.test.LockQueue")
    let semaphore = DispatchSemaphore(value: 1)
    
    private override init() {}
    
    func printTicket(target: String, data: [[String: Any]], openDrawer: Bool, callback: ((Bool) -> ())?) {
        lockQueue.async() {
            var hasErrorOccured = false
            _ = self.semaphore.wait(timeout: DispatchTime.distantFuture)
            
            if !self.initializePrinterObject() {
                self.errorOccurred(error: "initializePrinterObject")
                hasErrorOccured = true
            }
            
            if openDrawer {
                _ = self.sendPulse()
            }
            
            if !self.createReceiptData(data: data) {
                self.errorOccurred(error: "createReceiptData")
                hasErrorOccured = true
            }
            
            if !self.printData(target: target) {
                self.errorOccurred(error: "printData")
                hasErrorOccured = true
            }
            
            callback?(hasErrorOccured)
        }
    }
    
    func openDrawer(target: String) {
        lockQueue.async() {
            _ = self.semaphore.wait(timeout: DispatchTime.distantFuture)
            
            if !self.initializePrinterObject() {
                self.errorOccurred(error: "initializePrinterObject")
            }
            
            if !self.sendOpenDrawer(target: target) {
                self.errorOccurred(error: "sendOpenDrawer")
            }
        }
    }
    
    func initializePrinterObject() -> Bool {
        guard let printer = Epos2Printer(printerSeries: EPOS2_TM_M30.rawValue, lang: EPOS2_MODEL_ANK.rawValue) else {
            return false
        }
        self.printer = printer
        self.printer?.setReceiveEventDelegate(self)
        
        return true
    }
    
    func addImage(param: [String: Any]) -> Int32 {
        guard let image = param["data"] as? UIImage, let align = param["align"] as? String else {
            return EPOS2_ERR_FAILURE.rawValue
        }
        
        let scale = 500 / image.size.width
        let newHeight = image.size.height * scale
        let newWidth = image.size.width * scale
        var padding: CGFloat = 0
//        if align == "center" {
//            padding = 105
//        }
        UIGraphicsBeginImageContext(CGSize(width: newWidth + padding, height: newHeight))
        image.draw(in: CGRect(x: padding, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return printer!.add(newImage, x: 0, y: 0, width: Int(newImage!.size.width), height: Int(newImage!.size.height), color: EPOS2_PARAM_DEFAULT, mode: EPOS2_PARAM_DEFAULT, halftone: EPOS2_PARAM_DEFAULT, brightness: Double(EPOS2_PARAM_DEFAULT), compress: EPOS2_PARAM_DEFAULT)
    }
    
    func addLines(count: Int) -> Int32 {
        return printer?.addFeedLine(count) ?? EPOS2_ERR_FAILURE.rawValue
    }
    
    func addEmptyLine(param: [String: Any]) -> Int32 {
        var result = EPOS2_SUCCESS.rawValue
        
        guard let number = param["number"] as? Int else {
            return EPOS2_ERR_PARAM.rawValue
        }
        
        result = addLines(count: number)
        
        return result
    }
    
    func addStraightLine(param: [String: Any]) -> Int32 {
        guard let token = param["token"] as? String,
            let fontSize = param["font"] as? Int,
            let _ = param["size"] as? Int,
            let bold = param["bold"] as? Int else {
                return EPOS2_ERR_PARAM.rawValue
        }
        
        guard let printer = printer else {
            return EPOS2_ERR_FAILURE.rawValue
        }
        
        var result = printer.addTextAlign(EPOS2_ALIGN_CENTER.rawValue)
        
        if result != EPOS2_SUCCESS.rawValue {
            errorOccurred(error: "add text align")
            return EPOS2_ERR_TYPE_INVALID.rawValue
        }
        
        // Set text Boldness
        result = printer.addTextStyle(EPOS2_PARAM_DEFAULT, ul: EPOS2_PARAM_DEFAULT, em: Int32(bold), color: EPOS2_PARAM_DEFAULT)
        
        // Set fontSize
        result = printer.addTextSize(fontSize, height: fontSize)
        if result != EPOS2_SUCCESS.rawValue {
            errorOccurred(error: "add text size")
            return EPOS2_ERR_PARAM.rawValue
        }
        
        let textToPrint = String().padding(toLength: ticketLength / fontSize, withPad: token, startingAt: 0)
        let textData = NSMutableString()
        textData.append(textToPrint)
        result = printer.addText(textData as String)
        
        if result != EPOS2_SUCCESS.rawValue {
            errorOccurred(error: "add text")
            return EPOS2_ERR_PARAM.rawValue
        }
        
        printer.addFeedLine(1)
        
        return result
    }
    
    func addSimple(param: [String: Any]) -> Int32 {
        let result = addSimpleText(param: param)
        if result != EPOS2_SUCCESS.rawValue {
            return result
        }
        
        printer?.addFeedLine(1)
        
        return result
    }
    
    func addSimpleText(param: [String: Any]) -> Int32 {
        guard var textToPrint = param["data"] as? String,
            textToPrint != "",
            let fontWidth = param["fontWidth"] as? Int,
            let fontHeight = param["fontHeight"] as? Int,
            let align = param["align"] as? String,
            let bold = param["bold"] as? Int,
            let margin = param["margin"] as? Int else {
                return EPOS2_ERR_PARAM.rawValue
        }
        
        guard let printer = printer else {
            return EPOS2_ERR_FAILURE.rawValue
        }
        
        var result = EPOS2_SUCCESS.rawValue
        
        // render long text to multi lines if need
        // if has \n -> text already mananged
        let maxTextLengthForLine = (ticketLength / fontWidth - 2 * margin)
        textToPrint = renderLongTextIfNeeded(textToPrint: textToPrint, maxTextLengthForLine: maxTextLengthForLine, margin: margin, param: param, align: align)
        
        if align == "left" {
            // Align to the left
            var tmpTextToPrint = ""
            if param["shouldPutSpace"] == nil {
                tmpTextToPrint = String().padding(toLength: margin, withPad: " ", startingAt: 0) + textToPrint
            } else {
                tmpTextToPrint = textToPrint + String().padding(toLength: margin, withPad: " ", startingAt: 0)
            }
            textToPrint = tmpTextToPrint
            result = printer.addTextAlign(EPOS2_ALIGN_LEFT.rawValue)
        } else if align == "right" {
            // Align to the right
            textToPrint = textToPrint + String().padding(toLength: margin, withPad: " ", startingAt: 0)
            result = printer.addTextAlign(EPOS2_ALIGN_RIGHT.rawValue)
        } else {
            // Align Text to Center
            result = printer.addTextAlign(EPOS2_ALIGN_CENTER.rawValue)
        }
        
        if result != EPOS2_SUCCESS.rawValue {
            errorOccurred(error: "add text align")
            return EPOS2_ERR_TYPE_INVALID.rawValue
        }
        
        // Set text Boldness
        if let background = param["background"] as? Bool {
            let reverse = background ? EPOS2_TRUE : EPOS2_FALSE
            if reverse == EPOS2_TRUE {
                textToPrint = fillWithBlack(textToFill: textToPrint, param: param)
            }
            result = printer.addTextStyle(reverse, ul: EPOS2_PARAM_DEFAULT, em: Int32(bold), color: EPOS2_PARAM_DEFAULT)
        } else {
            result = printer.addTextStyle(EPOS2_FALSE, ul: EPOS2_PARAM_DEFAULT, em: Int32(bold), color: EPOS2_PARAM_DEFAULT)
        }
        
        // Set fontSize
        result = printer.addTextSize(fontWidth, height: fontHeight)
        if result != EPOS2_SUCCESS.rawValue {
            errorOccurred(error: "add text size")
            return EPOS2_ERR_PARAM.rawValue
        }
        
        // Set textData
        let textData = NSMutableString()
        textData.append(textToPrint)
        result = printer.addText(textData as String)
        if result != EPOS2_SUCCESS.rawValue {
            errorOccurred(error: "add text")
            return EPOS2_ERR_PARAM.rawValue
        }
        
        return result
    }
    
    func renderLongTextIfNeeded(textToPrint: String, maxTextLengthForLine: Int, margin: Int, param: [String: Any], align: String) -> String {
        if textToPrint.characters.count > maxTextLengthForLine && textToPrint.range(of:"\n") == nil {
            var spacingToLeft = margin
            if let leftSpace = param["spacingToLeft"] as? Int, leftSpace < maxTextLengthForLine {
                spacingToLeft = leftSpace
            }
            return renderLongTextToMultiLines(longText: textToPrint, length: maxTextLengthForLine, align: align, spacingToLeft: spacingToLeft)
        }
        return textToPrint
    }
    
    func fillWithBlack(textToFill: String, param: [String: Any]) -> String {
        guard let fontWidth = param["fontWidth"] as? Int,
            let _ = param["fontHeight"] as? Int else {
                return ""
        }
        
        let nbChars = ticketLength / fontWidth
        let lines = textToFill.components(separatedBy: "\n")
        var filledText = ""
        
        for line in lines {
            let padding = (nbChars - line.characters.count) > 0 ? (nbChars - line.characters.count) / 2 :  0
            
            var filledLine = String(repeating: " ", count: padding) + line
            filledLine = filledLine.padding(toLength: nbChars, withPad: " ", startingAt: 0)
            filledText.append((filledText.isEmpty ? "" : "\n") + filledLine)
        }
        
        return filledText
    }
    
    func addSimpleTextLine(param: [String: Any]) -> Int32 {
        guard let dataArray = param["data"] as? [String],
            let fontWidth = param["fontWidth"] as? Int,
            let fontHeight = param["fontHeight"] as? Int,
            let align = param["align"] as? String,
            let bold = param["bold"] as? Int,
            let margin = param["margin"] as? Int,
            let rightMargin = param["rightMargin"] as? Int,
            let string = dataArray.first else {
                return EPOS2_ERR_PARAM.rawValue
        }
        
        guard let printer = printer else {
            return EPOS2_ERR_FAILURE.rawValue
        }
        
        let totalStringSize = string.characters.count
        let numberOfSpaceToAdd = ticketLength / fontWidth - (2 * margin) - totalStringSize > 0 ? ticketLength / fontWidth - (2 * margin) - totalStringSize : 1
        
        var dico = [
            "fontWidth": fontWidth,
            "fontHeight": fontHeight,
            "align": align,
            "margin": margin,
            "bold": bold
            ] as [String: Any]
        
        dico["data"] = string + String().padding(toLength: numberOfSpaceToAdd, withPad: " ", startingAt: 0)
        _ = addSimpleText(param: dico)
        
        printer.addFeedLine(1)
        
        return EPOS2_SUCCESS.rawValue
    }
    
    func addDoubleTextLine(param: [String: Any]) -> Int32 {
        guard let dataArray = param["data"] as? [String],
            let fontWidth = param["fontWidth"] as? Int,
            let fontHeight = param["fontHeight"] as? Int,
            let align = param["align"] as? String,
            let bold = param["bold"] as? Int,
            let margin = param["margin"] as? Int,
            let rightMargin = param["rightMargin"] as? Int,
            let firstString = dataArray.first,
            let secondString = dataArray.last else {
                return EPOS2_ERR_PARAM.rawValue
        }
        
        guard let printer = printer else {
            return EPOS2_ERR_FAILURE.rawValue
        }
        
        let totalStringSize = firstString.characters.count + secondString.characters.count
        let numberOfSpaceToAdd = ticketLength / fontWidth - (2 * margin) - rightMargin - totalStringSize > 0 ? ticketLength / fontWidth - (2 * margin) - rightMargin - totalStringSize : 1
        
        var dico = [
            "fontWidth": fontWidth,
            "fontHeight": fontHeight,
            "align": align,
            "margin": margin,
            "bold": bold
            ] as [String: Any]
        
        dico["data"] = firstString + String().padding(toLength: numberOfSpaceToAdd, withPad: " ", startingAt: 0)
        _ = addSimpleText(param: dico)
        
        dico["data"] = secondString + String().padding(toLength: rightMargin, withPad: " ", startingAt: 0)
        _ = addSimpleText(param: dico)
        printer.addFeedLine(1)
        
        return EPOS2_SUCCESS.rawValue
    }
    
    func addTripleTextLine(param: [String: Any]) -> Int32 {
        guard let dataArray = param["data"] as? [String],
            let fontWidth = param["fontWidth"] as? Int,
            let fontHeight = param["fontHeight"] as? Int,
            let align = param["align"] as? String,
            let bold = param["bold"] as? Int,
            let margin = param["margin"] as? Int,
            let rightMargin = param["rightMargin"] as? Int,
            let firstString = dataArray.first,
            let thirdString = dataArray.last else {
                return EPOS2_ERR_PARAM.rawValue
        }
        
        let secondString = dataArray[1]
        
        let result = EPOS2_SUCCESS.rawValue
        
        let numberOfCharacters = firstString.characters.count + secondString.characters.count + thirdString.characters.count
        
        let interPriceSpace = (13 / fontWidth) - thirdString.characters.count > 0 ? (13 / fontWidth) - thirdString.characters.count : 1
        let spaceBetweenProductAndPrice = (ticketLength / fontWidth) - numberOfCharacters - interPriceSpace - (3 * margin) - rightMargin > 0 ? (ticketLength / fontWidth) - numberOfCharacters - interPriceSpace - (3 * margin) - rightMargin : 1
        
        var dico = [
            "fontWidth": fontWidth,
            "fontHeight": fontHeight,
            "align": align,
            "margin": margin,
            "bold": bold
            ] as [String: Any]
        
        dico["data"] = firstString
        _ = addSimpleText(param: dico)
        
        dico["data"] = String().padding(toLength: spaceBetweenProductAndPrice, withPad: " ", startingAt: 0) + secondString
        _ = addSimpleText(param: dico)
        
        dico["data"] = String().padding(toLength: interPriceSpace, withPad: " ", startingAt: 0) + thirdString + String(repeating: " ", count: rightMargin)
        
        _ = addSimpleText(param: dico)
        
        printer?.addFeedLine(1)
        
        return result
    }
    
    func addQuadrupleTextLine(param: [String: Any]) -> Int32 {
        guard let dataArray = param["data"] as? [String],
            let fontWidth = param["fontWidth"] as? Int,
            let fontHeight = param["fontHeight"] as? Int,
            let align = param["align"] as? String,
            let bold = param["bold"] as? Int,
            let margin = param["margin"] as? Int,
            let rightMargin = param["rightMargin"] as? Int,
            let firstString = dataArray.first,
            let fourthString = dataArray.last else {
                return EPOS2_ERR_PARAM.rawValue
        }
        
        let secondString = dataArray[1]
        let thirdString = dataArray[2]
        
        guard let printer = printer else {
            return EPOS2_ERR_FAILURE.rawValue
        }
        
        let numberOfCharacters = firstString.characters.count + secondString.characters.count + thirdString.characters.count + fourthString.characters.count
        let interPriceSpace = 13 - fourthString.characters.count > 0 ? 13 - fourthString.characters.count : 1
        let spaceBetweenProductAndPrice = (ticketLength / fontWidth) - numberOfCharacters - 1 - (4 * margin) - rightMargin - interPriceSpace > 0 ? (ticketLength / fontWidth) - numberOfCharacters - 1 - (4 * margin) - rightMargin - interPriceSpace : 1
        
        
        var dico = [
            "fontWidth": fontWidth,
            "fontHeight": fontHeight,
            "align": align,
            "margin": margin,
            "bold": bold
            ] as [String: Any]
        
        dico["data"] = firstString
        _ = addSimpleText(param: dico)
        
        dico["data"] = String().padding(toLength: spaceBetweenProductAndPrice, withPad: " ", startingAt: 0) + secondString
        dico["shouldPutSpace"] = false
        _ = addSimpleText(param: dico)
        
        dico["data"] = String().padding(toLength: interPriceSpace / 2, withPad: " ", startingAt: 0) + thirdString
        dico["shouldPutSpace"] = nil
        _ = addSimpleText(param: dico)
        
        dico["data"] = String().padding(toLength: interPriceSpace / 2 + 1, withPad: " ", startingAt: 0) + fourthString
        _ = addSimpleText(param: dico)
        
        printer.addFeedLine(1)
        
        return EPOS2_SUCCESS.rawValue
    }
    
    func addKitchenProductTextLine(param: [String: Any]) -> Int32 {
        guard let dataArray = param["data"] as? [String],
            let fontWidth = param["fontWidth"] as? Int,
            let fontHeight = param["fontHeight"] as? Int,
            let align = param["align"] as? String,
            let bold = param["bold"] as? Int,
            let margin = param["margin"] as? Int,
            let firstString = dataArray.first else {
                return EPOS2_ERR_PARAM.rawValue
        }
        
        guard let printer = printer else {
            return EPOS2_ERR_FAILURE.rawValue
        }
        
        let spacingToLeft = firstString.characters.count + margin + 1 // + one space
        var data = firstString
        if dataArray.count > 1 {
            data.append(" " + dataArray[1])
        }
        let dico = [
            "fontWidth": fontWidth,
            "fontHeight": fontHeight,
            "align": align,
            "margin": margin,
            "bold": bold,
            "spacingToLeft": spacingToLeft,
            "data": data
            ] as [String: Any]
        
        _ = addSimpleText(param: dico)
        
        printer.addFeedLine(1)
        
        return EPOS2_SUCCESS.rawValue
    }
    
    func addMultiple(param: [String: Any]) -> Int32 {
        guard let dataArray = param["data"] as? [String] else {
            return EPOS2_ERR_PARAM.rawValue
        }
        
        let result = EPOS2_SUCCESS.rawValue
        
        if dataArray.count == 1 {
            _ = addSimpleTextLine(param: param)
        } else if dataArray.count == 2 {
            _ = addDoubleTextLine(param: param)
        } else if dataArray.count == 3 {
            _ = addTripleTextLine(param: param)
        } else if dataArray.count == 4 {
            _ = addQuadrupleTextLine(param: param)
        }
        
        return result
    }
    
    func createReceiptData(data: [[String: Any]]) -> Bool {
        guard let printer = printer else {
            errorOccurred(error: "printer = nil")
            return false
        }
        
        // Set textSmooth
        var result = printer.addTextSmooth(EPOS2_TRUE)
        if result != EPOS2_SUCCESS.rawValue {
            errorOccurred(error: "add text smooth")
            return false
        }
        
        // Iterate through data to set param for each line
        for dico in data {
            if let type = dico["type"] as? Int,
                let ticketLineType = TicketLineType(rawValue: type) {
                switch (ticketLineType) {
                case .emptyLine:
                    _ = addEmptyLine(param: dico)
                    
                case .straightLine:
                    _ = addStraightLine(param: dico)
                    
                case .simpleText:
                    _ = addSimple(param: dico)
                    
                case .multipleText:
                    _ = addMultiple(param: dico)
                    
                case .image:
                    _ = addImage(param: dico)
                    
                case .kitchenProductText:
                    _ = addKitchenProductTextLine(param: dico)
                }
            }
        }
        
        _ = addLines(count: 3)
        
        result = printer.addCut(1)
        
        return true
    }
    
    func printData(target: String) -> Bool {
        var status: Epos2PrinterStatusInfo?
        
        guard let printer = printer else {
            errorOccurred(error: "PrintData - Printer Nil")
            return false
        }
        
        if !connectPrinter(target: target) {
            errorOccurred(error: "ConnectData - Printer Nil")
            return false
        }
        
        status = printer.getStatus()
        if !isPrintable(status: status) {
            errorOccurred(error: "PrintData - isPrintable")
            printer.disconnect()
            return false
        }
        
        let result = printer.sendData(Int(EPOS2_PARAM_DEFAULT))
        if result != EPOS2_SUCCESS.rawValue {
            errorOccurred(error: "sendData")
            printer.disconnect()
            return false
        }
        
        return true
    }
    
    func isPrintable(status: Epos2PrinterStatusInfo?) -> Bool {
        guard let status = status else {
            return false
        }
        
        if status.connection == EPOS2_FALSE || status.online == EPOS2_FALSE {
            return false
        }
        
        return true
    }
    
    func connectPrinter(target: String) -> Bool {
        var result = EPOS2_SUCCESS.rawValue
        
        guard let printer = printer else {
            errorOccurred(error: "Connect - Printer Nil")
            return false
        }
        
        result = printer.connect(target, timeout: Int(EPOS2_PARAM_DEFAULT))
        if result != EPOS2_SUCCESS.rawValue {
            errorOccurred(error: "connect")
            return false
        }
        
        result = printer.beginTransaction()
        if result != EPOS2_SUCCESS.rawValue {
            errorOccurred(error: "beginTransaction")
            printer.disconnect()
            return false
        }
        
        return true
    }
    
    func sendOpenDrawer(target: String) -> Bool {
        guard let printer = printer else {
            errorOccurred(error: "printer = nil")
            return false
        }
        
        if !connectPrinter(target: target) {
            errorOccurred(error: "connectError")
            return false
        }
        
        if !sendPulse() {
            errorOccurred(error: "pulse fail")
            return false
        }
        
        let result = printer.sendData(Int(EPOS2_PARAM_DEFAULT))
        if result != EPOS2_SUCCESS.rawValue {
            errorOccurred(error: "sendData")
            printer.disconnect()
            return false
        }
        
        return true
    }
    
    func sendPulse() -> Bool {
        let result = self.printer?.addPulse(EPOS2_PARAM_DEFAULT, time: EPOS2_PULSE_100.rawValue)
        if result != EPOS2_SUCCESS.rawValue {
            errorOccurred(error: "pulse - error")
            return false
        }
        
        return true
    }
    
    func errorOccurred(error: String) {
        finalizeObject()
        print(error)
    }
    
    func finalizeObject() {
        guard let printer = printer else {
            return
        }
        
        printer.clearCommandBuffer()
        printer.setReceiveEventDelegate(nil)
        self.printer = nil
        semaphore.signal()
    }
    
    func disconnectFromPrinter() {
        guard let printer = printer else {
            return
        }
        
        printer.endTransaction()
        printer.disconnect()
        finalizeObject()
    }
    
    public func onPtrReceive(_ printerObj: Epos2Printer!, code: Int32, status: Epos2PrinterStatusInfo!, printJobId: String!) {
        // Job Finished, do something
        disconnectFromPrinter()
    }
    
    //MARK: Helper
    /// Render long text to multiLines
    ///
    /// - Parameters:
    ///   - longText: text to
    ///   - length: max line length
    ///   - align: align
    ///   - spacingToLeft: spacing to left
    public func renderLongTextToMultiLines(longText: String, length: Int, align: String, spacingToLeft: Int = 0) -> String {
        let words = longText.components(separatedBy: " ")
        var lines = [String]()
        var result = ""
        
        for word in words {
            if (result.characters.count + word.characters.count + 1) < length {
                result += (result.isEmpty ? "" : " ") + word
            } else if (word.characters.count < length)  {
                lines.append(result + "\n")
                result = word
            } else {
                var currentWord = word
                while currentWord.characters.count > length {
                    let offset = min(length - result.characters.count - 1, currentWord.characters.count)
                    let index = currentWord.index(currentWord.startIndex, offsetBy: offset)
                    let subword = currentWord.substring(to: index)
                    currentWord = currentWord.substring(from: index)
                    lines.append(result + (result.isEmpty ? "" : " ") + subword + "\n")
                    result = ""
                }
                result = currentWord
            }
        }
        lines.append(result)
        result = ""
        let startCharIndex = (align == "left") ? spacingToLeft : 0
        for line in lines {
            if line == lines.first {
                result = line
                continue
            }
            result += String().padding(toLength: startCharIndex, withPad: " ", startingAt: 0) + line
        }
        
        return result
    }
}
