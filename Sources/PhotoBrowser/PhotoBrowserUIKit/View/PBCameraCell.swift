//
//  PBCameraCell.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit
import AVFoundation

class PBCameraCell: UICollectionViewCell {
    
    var imageView: UIImageView!
    
    var session: AVCaptureSession?
    
    var videoInput: AVCaptureDeviceInput?
    
    var photoOutput: AVCapturePhotoOutput?
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    deinit {
        session?.stopRunning()
        session = nil
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = CGRect(x: 0, y: 0, width: bounds.width / 3, height: bounds.width / 3)
        imageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        previewLayer?.frame = contentView.layer.bounds
    }
    
    func setupUI() {
        layer.masksToBounds = true
        layer.cornerRadius = PhotoConfiguration.default().cellCornerRadio
        
        imageView = UIImageView(image: getImage("pb_takePhoto"))
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        backgroundColor = .cameraCellBgColor
    }
    
    func startCapture() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        if !UIImagePickerController.isSourceTypeAvailable(.camera) || status == .denied {
            return
        }
        
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { (granted) in
                if granted {
                    DispatchQueue.main.async {
                        self.setupSession()
                    }
                }
            }
        } else {
            setupSession()
        }
    }
    
    func setupSession() {
        guard session == nil, (session?.isRunning ?? false) == false else {
            return
        }
        session?.stopRunning()
        if let input = videoInput {
            session?.removeInput(input)
        }
        if let output = photoOutput {
            session?.removeOutput(output)
        }
        session = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        
        guard let camera = backCamera() else {
            return
        }
        guard let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }
        videoInput = input
        photoOutput = AVCapturePhotoOutput()
        
        session = AVCaptureSession()
        
        if session?.canAddInput(input) == true {
            session?.addInput(input)
        }
        if session?.canAddOutput(photoOutput!) == true {
            session?.addOutput(photoOutput!)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session!)
        contentView.layer.masksToBounds = true
        previewLayer?.frame = contentView.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        contentView.layer.insertSublayer(previewLayer!, at: 0)
        
        session?.startRunning()
    }
    
    func backCamera() -> AVCaptureDevice? {
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices
        for device in devices {
            if device.position == .back {
                return device
            }
        }
        return nil
    }
    
}


extension PBCameraCell: AVCapturePhotoCaptureDelegate {
    
}
