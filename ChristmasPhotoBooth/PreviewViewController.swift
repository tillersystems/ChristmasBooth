//
//  PreviewViewController.swift
//  ChristmasPhotoBooth
//
//  Created by Felix Carrard on 13/12/2017.
//  Copyright © 2017 TillerSystems. All rights reserved.
//

import UIKit
import TillerPrinter
import Photos

class PreviewViewController: UIViewController {
    
    @IBOutlet weak var fullPreviewImageView: UIImageView!
    @IBOutlet weak var previewImageView: UIImageView!
    
    var currentImage: UIImage? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let firstCrop = cropToBounds(image: currentImage!, width: 720, height: 1024)
        fullPreviewImageView.image = firstCrop
        previewImageView.image = cropToBounds(image: firstCrop, width: 720, height: 720, y: 150)
        // Do any additional setup after loading the view.
    }

    public func setupImage(image: UIImage) {
        currentImage = image
    }
    
    func cropToBounds(image: UIImage, width: Double, height: Double, y: CGFloat = 0) -> UIImage {
        let contextImage: UIImage = UIImage(cgImage: image.cgImage!)
        
        var posX: CGFloat = y
        var posY: CGFloat = 0
        var cgwidth: CGFloat = CGFloat(height)
        var cgheight: CGFloat = CGFloat(width)
        // See what size is longer and create the center off of that
        
        
        let rect: CGRect = CGRect(x: posX, y: posY, width: cgwidth, height: cgheight)
        // Create bitmap image from context using the rect
        let imageRef: CGImage = contextImage.cgImage!.cropping(to: rect)!
        
        // Create a new image based on the imageRef and rotate back to the original orientation
        let image: UIImage = UIImage(cgImage: imageRef, scale: image.scale, orientation: image.imageOrientation)
        
        return image
    }

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    @IBAction func printPicture(_ sender: Any) {
        var model: [[String: Any]] = [[:]]
        if let path = Bundle.main.path(forResource: "PictureTicket", ofType: "plist") {
            if let array = NSArray(contentsOfFile: path) as? [[String: Any]] {
                model = array
            }
        }
        
        let value = [
            "logo": previewImageView.image!,
            "message": "Merry Christmas from Tiller",
            "emptyLine": "OK"
            ] as [String: Any]
        
        _ = TillerPrinter.sharedInstance.renderTicket(target: PrinterManager.shared.target, data: value, model: model, openDrawer: true, name: "Test", callback: nil)
        
        
        UIImageWriteToSavedPhotosAlbum(previewImageView.image!, nil, nil, nil)
//        try? PHPhotoLibrary.shared().performChangesAndWait {
//            PHAssetChangeRequest.creationRequestForAsset(from: self.previewImageView.image!)
//        }
        self.dismiss(animated: false, completion: nil)
    }
    
    @IBAction func retakePicture(_ sender: Any) {
        UIImageWriteToSavedPhotosAlbum(previewImageView.image!, nil, nil, nil)
        self.dismiss(animated: false, completion: nil)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
