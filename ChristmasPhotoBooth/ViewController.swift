//
//  ViewController.swift
//  ChristmasPhotoBooth
//
//  Created by Felix Carrard on 13/12/2017.
//  Copyright © 2017 TillerSystems. All rights reserved.
//

import UIKit
import TillerPrinter

class ViewController: UIViewController, DiscoveryManagerDelegate {
    
    let discoveryManager = DiscoveryManager()
    @IBOutlet weak var previewCaptureView: UIView!
    @IBOutlet weak var animatedLabel: AnimatedLabel!
    @IBOutlet weak var pictureButton: UIButton!
    
    let cameraController = CameraController()
    
    override var prefersStatusBarHidden: Bool { return true }
    
    override func viewDidLoad() {
        
        func configureCameraController() {
            cameraController.prepare {(error) in
                if let error = error {
                    print(error)
                }
                
                try? self.cameraController.displayPreview(on: self.previewCaptureView)
            }
        }
        
        configureCameraController()
        discoverDevice()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func triggerPicture() {
        cameraController.captureImage {(image, error) in
            guard let image = image else {
                print(error ?? "Image capture error")
                return
            }
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let controller = storyboard.instantiateViewController(withIdentifier: "PreviewViewController") as? PreviewViewController {
                controller.modalPresentationStyle = .overCurrentContext
                controller.modalTransitionStyle = .crossDissolve
                controller.setupImage(image: image)
                self.present(controller, animated: false, completion: nil)
            }
        }
    }
    
    @IBAction func takePicture(_ sender: Any) {
        pictureButton.isHidden = true
        animatedLabel.isHidden = false
        animatedLabel.count(from: 3, to: 0, duration: 3)
        animatedLabel.completion = {
            self.triggerPicture()
            self.animatedLabel.isHidden = true
            self.pictureButton.isHidden = false
        }
    }
    
    func discoverDevice() {
        discoveryManager.delegate = self
        discoveryManager.discoverDevices()
    }
    
    func didDiscoverDevice(deviceInfo: Epos2DeviceInfo) {
        PrinterManager.shared.target = deviceInfo.target
        if let macAdress = deviceInfo.macAddress, macAdress != "" {
            PrinterManager.shared.target = "TCP:\(macAdress)"
        }
    }
}

