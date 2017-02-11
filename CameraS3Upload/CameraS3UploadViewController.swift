//
//  ViewController.swift
//  CameraS3Upload
//
//  Created by Dragan Basta on 1/26/17.
//  Copyright © 2017 Dragan Basta. All rights reserved.
//

import UIKit
import AVFoundation


struct CustomColor {
    let red: Int
    let green: Int
    let blue: Int
}

class CameraS3UploadViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    
    enum Constants {
        static let noOfRepeats = 5
        static let timeBetweenShots = 2 //In seconds
        static let timeInterval = 1 //Timer interval (could be less than 1 second)
    }
    
    let buttonBckColor = CustomColor(red: 255, green: 86, blue: 52)
    
    //MARK: Properties
    @IBOutlet weak var cameraFeedView: UIImageView!
    
    var cameraCaptureSesssion: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput!
    
    var uploadingManager = CameraS3UploadModel()
    var uploadRepeater = Timer()
    
    @IBOutlet weak var repeatsLeftLabel: UILabel!
    @IBOutlet weak var timeLeftLabel: UILabel!
    @IBOutlet weak var captureButton: UIButton!
    
    var repeatsLeft = Constants.noOfRepeats
    var timeLeft = Constants.timeBetweenShots
    
    var updateTime = Timer()
    
    //MARK: Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Init labels
        updateLabels()
        
        //Init camera video stream
        cameraCaptureSesssion = AVCaptureSession()
        cameraCaptureSesssion.sessionPreset = AVCaptureSessionPreset1920x1080
        stillImageOutput = AVCapturePhotoOutput()
        
        let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if (cameraCaptureSesssion.canAddInput(input)) {
                cameraCaptureSesssion.addInput(input)
                if (cameraCaptureSesssion.canAddOutput(stillImageOutput)) {
                    cameraCaptureSesssion.addOutput(stillImageOutput)
                    
                    cameraCaptureSesssion.startRunning()
                    
                    let captureVideoLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer.init(session: cameraCaptureSesssion)
                    captureVideoLayer.frame = cameraFeedView.bounds
                    captureVideoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
                    cameraFeedView.layer.addSublayer(captureVideoLayer)
                }
            }
        }
        catch {
            print(error)
        }
        
        //TODO: App should not try every second to upload(research on notifications)
        //Start timer for uploading photos
        //App tries to upload photos every second(in order to check for new elements in array)
        //It is simple way, because i have no experience with notification systems
        //It is better to somehow array notify the waiting thread about new element
        uploadRepeater = Timer.scheduledTimer(timeInterval: 1,
                                              target: uploadingManager,
                                              selector: #selector(CameraS3UploadModel.uploadPhotos),
                                              userInfo: nil,
                                              repeats: true)
    }

    //MARK: Taking photo methods
    @IBAction func takePhoto(_ sender: Any) {
        //Start period timer, in this case it is 2 seconds pause between shots
        updateTime = Timer.scheduledTimer(timeInterval: Double(Constants.timeInterval),
                                          target: self,
                                          selector: #selector(updateLabelsAndTakePhoto),
                                          userInfo: nil,
                                          repeats: true)
        takeBracketedPhotos()
        captureButton.isEnabled = false
        captureButton.backgroundColor = UIColor.getColorFrom(customColor: buttonBckColor, alpha: 0.2)
    }
    
    func updateLabelsAndTakePhoto(){
        //Periodically called function
        if timeLeft == 0 {
            takeBracketedPhotos()
            timeLeft = Constants.timeBetweenShots
            repeatsLeft -= 1
        } else {
            timeLeft -= Constants.timeInterval
        }
        if (repeatsLeft == 0) {
            repeatsLeft = Constants.noOfRepeats
            timeLeft = Constants.timeBetweenShots
            updateTime.invalidate()
            captureButton.isEnabled = true
            captureButton.backgroundColor = UIColor.getColorFrom(customColor: buttonBckColor, alpha: 0.5)
        }
        
        updateLabels()
    }
    
    func takeBracketedPhotos(){
        //Init settings
        guard stillImageOutput.maxBracketedCapturePhotoCount >= 3 else { return }
        
        let settingsForMonitoring = AVCapturePhotoSettings()
        settingsForMonitoring.isHighResolutionPhotoEnabled = true
        
        let makeSettings = AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings
        let bracketedStillImageSettings = [-1, 0, 1].map { makeSettings(Float($0))! }
        
        let photoSettings = AVCapturePhotoBracketSettings(rawPixelFormatType: 0,
                                                          processedFormat: [AVVideoCodecKey : AVVideoCodecJPEG],
                                                          bracketedSettings: bracketedStillImageSettings)
        
        stillImageOutput?.capturePhoto(with: photoSettings, delegate: self)
        
        //Animate UI so user nows the shot is taken
        UIView.animate(withDuration: 0.1,
                       delay: 0,
                       options: UIViewAnimationOptions.curveLinear,
                       animations: {
                        self.cameraFeedView.alpha = 0.8
        },
                       completion: { (finished: Bool) in
                        self.cameraFeedView.alpha = 1.0
        })
    }

    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
                 previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 bracketSettings: AVCaptureBracketedStillImageSettings?,
                 error: Error?) {
        
        if let photoSampleBuffer = photoSampleBuffer {
            let photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
            let image = UIImage(data: photoData!)
            
            uploadingManager.imagesToUploadQueue.append(image)
        }
    }
    
    //MARK: Util methods
    func updateLabels(){
        timeLeftLabel.text = "Time: " + String(timeLeft)
        repeatsLeftLabel.text = "Repeats: " + String(repeatsLeft)
    }
    
    //MARK: Device requirements
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}

extension UIColor{
    class func getColorFrom(customColor: CustomColor, alpha: Double) -> UIColor{
        return UIColor(red: CGFloat(customColor.red)/255, green: CGFloat(customColor.green)/255, blue: CGFloat(customColor.blue)/255, alpha: CGFloat(alpha))
    }
}


