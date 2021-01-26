//
//  PBCustomCamera.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/5.
//

import UIKit
import AVFoundation
import CoreMotion

open class PBCustomCamera: UIViewController, CAAnimationDelegate {

    struct Layout {
        
        static let bottomViewH: CGFloat = 150
        
        static let largeCircleRadius: CGFloat = 85
        
        static let smallCircleRadius: CGFloat = 62
        
        static let largeCircleRecordScale: CGFloat = 1.2
        
        static let smallCircleRecordScale: CGFloat = 0.7
        
    }
    
    @objc public var takeDoneBlock: ( (UIImage?, URL?) -> Void )?
    
    var tipsLabel: UILabel!
    
    var hideTipsTimer: Timer?
    
    var bottomView: UIView!
    
    var largeCircleView: UIVisualEffectView!
    
    var smallCircleView: UIView!
    
    var animateLayer: CAShapeLayer!
    
    var retakeBtn: UIButton!
    
    var editBtn: UIButton!
    
    var doneBtn: UIButton!
    
    var dismissBtn: UIButton!
    
    var switchCameraBtn: UIButton!
    
    var focusCursorView: UIImageView!
    
    var takedImageView: UIImageView!
    
    var takedImage: UIImage?
    
    var videoUrl: URL?
    
    var motionManager: CMMotionManager?
    
    var orientation: AVCaptureVideoOrientation = .portrait
    
    let session = AVCaptureSession()
    
    var videoInput: AVCaptureDeviceInput?
    
    var imageOutput: AVCapturePhotoOutput!
    
    var movieFileOutput: AVCaptureMovieFileOutput!
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var recordVideoPlayerLayer: AVPlayerLayer?
    
    var cameraConfigureFinish = false
    
    var layoutOK = false
    
    var dragStart = false
    
    var viewDidAppearCount = 0
    
    var restartRecordAfterSwitchCamera = false
    
    var cacheVideoOrientation: AVCaptureVideoOrientation = .portrait
    
    var recordUrls: [URL] = []
    
    // 仅支持竖屏
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    public override var prefersStatusBarHidden: Bool {
        return true
    }
    
    deinit {
        cleanTimer()
        if session.isRunning {
            session.stopRunning()
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    @objc public init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            return
        }
        setupCamera()
        observerDeviceMotion()
        addNotification()
        
        AVCaptureDevice.requestAccess(for: .video) { (videoGranted) in
            if videoGranted {
                if PhotoConfiguration.default().allowRecordVideo {
                    AVCaptureDevice.requestAccess(for: .audio) { (audioGranted) in
                        if !audioGranted {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                self.showAlertAndDismissAfterDoneAction(message: String(format: "请在iPhone的\"设置-隐私-麦克风\"选项中，允许%@访问你的麦克风", getAppName()))
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                    self.showAlertAndDismissAfterDoneAction(message: String(format: "请在iPhone的\"设置-隐私-相机\"选项中，允许%@访问你的相机", getAppName()))
                })
            }
        }
        if PhotoConfiguration.default().allowRecordVideo {
            try? AVAudioSession.sharedInstance().setCategory(.playAndRecord)
            try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        }
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            showAlertAndDismissAfterDoneAction(message: "相机不可用")
        } else if !PhotoConfiguration.default().allowTakePhoto, !PhotoConfiguration.default().allowRecordVideo {
            #if DEBUG
            fatalError("参数配置错误")
            #else
            showAlertAndDismissAfterDoneAction(message: "相机参数配置错误")
            #endif
        } else if cameraConfigureFinish, viewDidAppearCount == 0 {
            showTipsLabel(animate: true)
            session.startRunning()
            setFocusCusor(point: view.center)
        }
        viewDidAppearCount += 1
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        motionManager?.stopDeviceMotionUpdates()
        motionManager = nil
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session.stopRunning()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !layoutOK else { return }
        layoutOK = true
        
        var insets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        if #available(iOS 11.0, *) {
            insets = view.safeAreaInsets
        }
        let previewLayerY: CGFloat = isIPhoneXSeries() ? 20 : 0
        previewLayer?.frame = CGRect(x: 0, y: previewLayerY, width: view.bounds.width, height: view.bounds.height)
        recordVideoPlayerLayer?.frame = view.bounds
        takedImageView.frame = view.bounds
        
        bottomView.frame = CGRect(x: 0, y: view.bounds.height-insets.bottom-PBCustomCamera.Layout.bottomViewH-50, width: view.bounds.width, height: PBCustomCamera.Layout.bottomViewH)
        let largeCircleH = PBCustomCamera.Layout.largeCircleRadius
        largeCircleView.frame = CGRect(x: (view.bounds.width-largeCircleH)/2, y: (PBCustomCamera.Layout.bottomViewH-largeCircleH)/2, width: largeCircleH, height: largeCircleH)
        let smallCircleH = PBCustomCamera.Layout.smallCircleRadius
        smallCircleView.frame = CGRect(x: (view.bounds.width-smallCircleH)/2, y: (PBCustomCamera.Layout.bottomViewH-smallCircleH)/2, width: smallCircleH, height: smallCircleH)
        
        dismissBtn.frame = CGRect(x: 60, y: (PBCustomCamera.Layout.bottomViewH-25)/2, width: 25, height: 25)
        
        tipsLabel.frame = CGRect(x: 0, y: bottomView.frame.minY-20, width: view.bounds.width, height: 20)
        
        retakeBtn.frame = CGRect(x: 30, y: insets.top+10, width: 28, height: 28)
        switchCameraBtn.frame = CGRect(x: view.bounds.width-30-28, y: insets.top+10, width: 28, height: 28)

        editBtn.frame = CGRect(x: 20, y: view.bounds.height - insets.bottom - PBLayout.bottomToolBtnH - 40, width: 40, height: PBLayout.bottomToolBtnH)
        
        doneBtn.frame = CGRect(x: view.bounds.width - 40 - 20, y: view.bounds.height - insets.bottom - PBLayout.bottomToolBtnH - 40, width: 40, height: PBLayout.bottomToolBtnH)
    }
    
    func setupUI() {
        view.backgroundColor = .black
        
        takedImageView = UIImageView()
        takedImageView.backgroundColor = .black
        takedImageView.isHidden = true
        takedImageView.contentMode = .scaleAspectFit
        view.addSubview(takedImageView)
        
        focusCursorView = UIImageView(image: getImage("pb_focus"))
        focusCursorView.contentMode = .scaleAspectFit
        focusCursorView.clipsToBounds = true
        focusCursorView.frame = CGRect(x: 0, y: 0, width: 70, height: 70)
        focusCursorView.alpha = 0
        view.addSubview(focusCursorView)
        
        tipsLabel = UILabel()
        tipsLabel.font = UIFont.systemFont(ofSize: 14)
        tipsLabel.textColor = .white
        tipsLabel.textAlignment = .center
        tipsLabel.alpha = 0
        if PhotoConfiguration.default().allowTakePhoto, PhotoConfiguration.default().allowRecordVideo {
            tipsLabel.text = "轻触拍照，按住摄像"
        } else if PhotoConfiguration.default().allowTakePhoto {
            tipsLabel.text = "轻触拍照"
        } else if PhotoConfiguration.default().allowRecordVideo {
            tipsLabel.text = "按住摄像"
        }
        
        view.addSubview(tipsLabel)
        
        bottomView = UIView()
        view.addSubview(bottomView)
        
        dismissBtn = UIButton(type: .custom)
        dismissBtn.setImage(getImage("pb_arrow_down"), for: .normal)
        dismissBtn.addTarget(self, action: #selector(dismissBtnClick), for: .touchUpInside)
        dismissBtn.adjustsImageWhenHighlighted = false
        dismissBtn.enlargeValidTouchArea(inset: 30)
        bottomView.addSubview(dismissBtn)
        if #available(iOS 13.0, *) {
            largeCircleView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
        } else {
            largeCircleView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        }
        largeCircleView.layer.masksToBounds = true
        largeCircleView.layer.cornerRadius = PBCustomCamera.Layout.largeCircleRadius / 2
        bottomView.addSubview(largeCircleView)
        
        smallCircleView = UIView()
        smallCircleView.layer.masksToBounds = true
        smallCircleView.layer.cornerRadius = PBCustomCamera.Layout.smallCircleRadius / 2
        smallCircleView.isUserInteractionEnabled = false
        smallCircleView.backgroundColor = .white
        bottomView.addSubview(smallCircleView)
        
        animateLayer = CAShapeLayer()
        let animateLayerRadius = PBCustomCamera.Layout.largeCircleRadius
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: animateLayerRadius, height: animateLayerRadius), cornerRadius: animateLayerRadius/2)
        animateLayer.path = path.cgPath
        animateLayer.strokeColor = RGB(80, 169, 56).cgColor
        animateLayer.fillColor = UIColor.clear.cgColor
        animateLayer.lineWidth = 8
        
        var takePictureTap: UITapGestureRecognizer?
        if PhotoConfiguration.default().allowTakePhoto {
            takePictureTap = UITapGestureRecognizer(target: self, action: #selector(takePicture))
            largeCircleView.addGestureRecognizer(takePictureTap!)
        }
        if PhotoConfiguration.default().allowRecordVideo {
            let recordLongPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
            recordLongPress.minimumPressDuration = 0.3
            recordLongPress.delegate = self
            largeCircleView.addGestureRecognizer(recordLongPress)
            takePictureTap?.require(toFail: recordLongPress)
        }
        
        retakeBtn = UIButton(type: .custom)
        retakeBtn.setImage(getImage("pb_retake"), for: .normal)
        retakeBtn.addTarget(self, action: #selector(retakeBtnClick), for: .touchUpInside)
        retakeBtn.isHidden = true
        retakeBtn.adjustsImageWhenHighlighted = false
        retakeBtn.enlargeValidTouchArea(inset: 30)
        view.addSubview(retakeBtn)
        
        let cameraCount = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified).devices.count
        switchCameraBtn = UIButton(type: .custom)
        switchCameraBtn.setImage(getImage("pb_toggle_camera"), for: .normal)
        switchCameraBtn.addTarget(self, action: #selector(switchCameraBtnClick), for: .touchUpInside)
        switchCameraBtn.adjustsImageWhenHighlighted = false
        switchCameraBtn.enlargeValidTouchArea(inset: 30)
        switchCameraBtn.isHidden = cameraCount <= 1
        view.addSubview(switchCameraBtn)
        
        editBtn = UIButton(type: .custom)
        editBtn.titleLabel?.font = PBLayout.bottomToolTitleFont
        editBtn.setTitle("编辑", for: .normal)
        editBtn.setTitleColor(UIColor.white, for: .normal)
        editBtn.addTarget(self, action: #selector(editBtnClick), for: .touchUpInside)
        editBtn.isHidden = true
        // 字体周围添加一点阴影
        editBtn.titleLabel?.layer.shadowColor = UIColor.black.withAlphaComponent(0.3).cgColor
        editBtn.titleLabel?.layer.shadowOffset = .zero
        editBtn.titleLabel?.layer.shadowOpacity = 1;
        view.addSubview(editBtn)
        
        doneBtn = UIButton(type: .custom)
        doneBtn.titleLabel?.font = PBLayout.bottomToolTitleFont
        doneBtn.setTitle("确定", for: .normal)
        doneBtn.setTitleColor(UIColor.white, for: .normal)
        doneBtn.backgroundColor = RGB(80, 169, 56)
        doneBtn.addTarget(self, action: #selector(doneBtnClick), for: .touchUpInside)
        doneBtn.isHidden = true
        doneBtn.layer.masksToBounds = true
        doneBtn.layer.cornerRadius = PBLayout.bottomToolBtnCornerRadius
        view.addSubview(doneBtn)
        
        let focusCursorTap = UITapGestureRecognizer(target: self, action: #selector(adjustFocusPoint))
        focusCursorTap.delegate = self
        view.addGestureRecognizer(focusCursorTap)
        
        if PhotoConfiguration.default().allowRecordVideo {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(adjustCameraFocus(_:)))
            pan.delegate = self
            pan.maximumNumberOfTouches = 1
            view.addGestureRecognizer(pan)
            
            recordVideoPlayerLayer = AVPlayerLayer()
            recordVideoPlayerLayer?.backgroundColor = UIColor.black.cgColor
            recordVideoPlayerLayer?.videoGravity = .resizeAspect
            recordVideoPlayerLayer?.isHidden = true
            view.layer.insertSublayer(recordVideoPlayerLayer!, at: 0)
            
            NotificationCenter.default.addObserver(self, selector: #selector(recordVideoPlayFinished), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        }
        
        let pinchGes = UIPinchGestureRecognizer(target: self, action: #selector(pinchToAdjustCameraFocus(_:)))
        view.addGestureRecognizer(pinchGes)
    }
    
    func observerDeviceMotion() {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.observerDeviceMotion()
            }
            return
        }
        motionManager = CMMotionManager()
        motionManager?.deviceMotionUpdateInterval = 0.5
        
        if motionManager?.isDeviceMotionAvailable == true {
            motionManager?.startDeviceMotionUpdates(to: OperationQueue.main, withHandler: { (motion, error) in
                if let _ = motion {
                    self.handleDeviceMotion(motion!)
                }
            })
        } else {
            motionManager = nil
        }
    }
    
    func handleDeviceMotion(_ motion: CMDeviceMotion) {
        let x = motion.gravity.x
        let y = motion.gravity.y
        
        if abs(y) >= abs(x) {
            if y >= 0 {
                orientation = .portraitUpsideDown
            } else {
                orientation = .portrait
            }
        } else {
            if x >= 0 {
                orientation = .landscapeLeft
            } else {
                orientation = .landscapeRight
            }
        }
    }
    
    func setupCamera() {
        guard let backCamera = getCamera(position: .back) else { return }
        
        guard let input = try? AVCaptureDeviceInput(device: backCamera) else { return }
        // 相机画面输入流
        videoInput = input
        // 照片输出流
        imageOutput = AVCapturePhotoOutput()
        
        // 音频输入流
        var audioInput: AVCaptureDeviceInput?
        if PhotoConfiguration.default().allowRecordVideo, let microphone = getMicrophone() {
            audioInput = try? AVCaptureDeviceInput(device: microphone)
        }
        
        let preset = PhotoConfiguration.default().sessionPreset.avSessionPreset
        if session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
        } else {
            session.sessionPreset = .hd1280x720
        }
        
        movieFileOutput = AVCaptureMovieFileOutput()
        // 解决视频录制超过10s没有声音的bug
        movieFileOutput.movieFragmentInterval = .invalid
        
        // 将视频及音频输入流添加到session
        if let vi = videoInput, session.canAddInput(vi) {
            session.addInput(vi)
        }
        if let ai = audioInput, session.canAddInput(ai) {
            session.addInput(ai)
        }
        // 将输出流添加到session
        if session.canAddOutput(imageOutput) {
            session.addOutput(imageOutput)
        }
        if session.canAddOutput(movieFileOutput) {
            session.addOutput(movieFileOutput)
        }
        // 预览layer
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspect
        view.layer.masksToBounds = true
        view.layer.insertSublayer(previewLayer!, at: 0)
        
        cameraConfigureFinish = true
    }
    
    func getCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: position).devices
        for device in devices {
            if device.position == position {
                return device
            }
        }
        return nil
    }
    
    func getMicrophone() -> AVCaptureDevice? {
        return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone], mediaType: .audio, position: .unspecified).devices.first
    }
    
    func addNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        
        if PhotoConfiguration.default().allowRecordVideo {
            NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }
    
    func showAlertAndDismissAfterDoneAction(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "确定", style: .default) { (_) in
            self.dismiss(animated: true, completion: nil)
        }
        alert.addAction(action)
        showDetailViewController(alert, sender: nil)
    }
    
    func showTipsLabel(animate: Bool) {
        tipsLabel.layer.removeAllAnimations()
        if animate {
            UIView.animate(withDuration: 0.25) {
                self.tipsLabel.alpha = 1
            }
        } else {
            tipsLabel.alpha = 1
        }
        startHideTipsLabelTimer()
    }
    
    func hideTipsLabel(animate: Bool) {
        cleanTimer()
        tipsLabel.layer.removeAllAnimations()
        if animate {
            UIView.animate(withDuration: 0.25) {
                self.tipsLabel.alpha = 0
            }
        } else {
            tipsLabel.alpha = 0
        }
    }
    
    func startHideTipsLabelTimer() {
        cleanTimer()
        hideTipsTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false, block: { (timer) in
            self.hideTipsLabel(animate: true)
        })
    }
    
    func cleanTimer() {
        hideTipsTimer?.invalidate()
        hideTipsTimer = nil
    }
    
    @objc func appWillResignActive() {
        if session.isRunning {
            dismiss(animated: true, completion: nil)
        }
        if videoUrl != nil, let player = recordVideoPlayerLayer?.player {
            player.pause()
        }
    }
    
    @objc func appDidBecomeActive() {
        if videoUrl != nil, let player = recordVideoPlayerLayer?.player {
            player.play()
        }
    }
    
    @objc func dismissBtnClick() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func retakeBtnClick() {
        session.startRunning()
        resetSubViewStatus()
        takedImage = nil
        stopRecordAnimation()
        if let url = videoUrl {
            recordVideoPlayerLayer?.player?.pause()
            recordVideoPlayerLayer?.player = nil
            recordVideoPlayerLayer?.isHidden = true
            videoUrl = nil
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    @objc func switchCameraBtnClick() {
        do {
            guard !restartRecordAfterSwitchCamera else {
                return
            }
            
            guard let currInput = videoInput else {
                return
            }
            var newVideoInput: AVCaptureDeviceInput?
            if currInput.device.position == .back, let front = getCamera(position: .front) {
                newVideoInput = try AVCaptureDeviceInput(device: front)
            } else if currInput.device.position == .front, let back = getCamera(position: .back) {
                newVideoInput = try AVCaptureDeviceInput(device: back)
            } else {
                return
            }
            
            let zoomFactor = currInput.device.videoZoomFactor
            
            if let ni = newVideoInput {
                session.beginConfiguration()
                session.removeInput(currInput)
                if session.canAddInput(ni) {
                    session.addInput(ni)
                    videoInput = ni
                    ni.device.videoZoomFactor = zoomFactor
                } else {
                    session.addInput(currInput)
                }
                session.commitConfiguration()
                if movieFileOutput.isRecording {
                    let pauseTime = animateLayer.convertTime(CACurrentMediaTime(), from: nil)
                    animateLayer.speed = 0
                    animateLayer.timeOffset = pauseTime
                    restartRecordAfterSwitchCamera = true
                }
            }
        } catch {
            print("切换摄像头失败 \(error.localizedDescription)")
        }
    }
    
    @objc func editBtnClick() {
        guard let image = takedImage else {
            return
        }
        PBEditImageViewController.showEditImageVC(parentVC: self, image: image) { [weak self] (ei, _) in
            self?.takedImage = ei
            self?.takedImageView.image = ei
        }
    }
    
    @objc func doneBtnClick() {
        recordVideoPlayerLayer?.player?.pause()
        recordVideoPlayerLayer?.player = nil
        dismiss(animated: true) {
            self.takeDoneBlock?(self.takedImage, self.videoUrl)
        }
    }
    
    // 点击拍照
    @objc func takePicture() {
        let connection = imageOutput.connection(with: .video)
        connection?.videoOrientation = orientation
        if videoInput?.device.position == .front, connection?.isVideoMirroringSupported == true {
            connection?.isVideoMirrored = true
        }
        var setting:AVCapturePhotoSettings
        if #available(iOS 11.0, *) {
            setting = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        } else {
            setting = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecJPEG])
        }
        if videoInput?.device.hasFlash == true {
            setting.flashMode = PhotoConfiguration.default().cameraFlashMode.avFlashMode
        }
        imageOutput.capturePhoto(with: setting, delegate: self)
    }
    
    // 长按录像
    @objc func longPressAction(_ longGes: UILongPressGestureRecognizer) {
        if longGes.state == .began {
            startRecord()
        } else if longGes.state == .cancelled || longGes.state == .ended {
            finishRecord()
        }
    }
    
    // 调整焦点
    @objc func adjustFocusPoint(_ tap: UITapGestureRecognizer) {
        guard session.isRunning else {
            return
        }
        let point = tap.location(in: view)
        if point.y > bottomView.frame.minY - 30 {
            return
        }
        setFocusCusor(point: point)
    }
    
    func setFocusCusor(point: CGPoint) {
        focusCursorView.center = point
        focusCursorView.layer.removeAllAnimations()
        focusCursorView.alpha = 1
        focusCursorView.layer.transform = CATransform3DMakeScale(1.2, 1.2, 1)
        UIView.animate(withDuration: 0.5, animations: {
            self.focusCursorView.layer.transform = CATransform3DIdentity
        }) { (_) in
            self.focusCursorView.alpha = 0
        }
        // ui坐标转换为摄像头坐标
        let cameraPoint = previewLayer?.captureDevicePointConverted(fromLayerPoint: point) ?? view.center
        focusCamera(mode: .autoFocus, exposureMode: .autoExpose, point: cameraPoint)
    }
    
    // 调整焦距
    @objc func adjustCameraFocus(_ pan: UIPanGestureRecognizer) {
        let convertRect = bottomView.convert(largeCircleView.frame, to: view)
        let point = pan.location(in: view)
        
        if pan.state == .began {
            if !convertRect.contains(point) {
                return
            }
            dragStart = true
            startRecord()
        } else if pan.state == .changed {
            guard dragStart else {
                return
            }
            let maxZoomFactor = getMaxZoomFactor()
            var zoomFactor = (convertRect.midY - point.y) / convertRect.midY * maxZoomFactor
            zoomFactor = max(1, min(zoomFactor, maxZoomFactor))
            setVideoZoomFactor(zoomFactor)
        } else if pan.state == .cancelled || pan.state == .ended {
            guard dragStart else {
                return
            }
            dragStart = false
            finishRecord()
        }
    }
    
    @objc func pinchToAdjustCameraFocus(_ pinch: UIPinchGestureRecognizer) {
        guard let device = videoInput?.device else {
            return
        }
        
        var zoomFactor = device.videoZoomFactor * pinch.scale
        zoomFactor = max(1, min(zoomFactor, getMaxZoomFactor()))
        setVideoZoomFactor(zoomFactor)
        
        pinch.scale = 1
    }
    
    func getMaxZoomFactor() -> CGFloat {
        guard let device = videoInput?.device else {
            return 1
        }
        if #available(iOS 11.0, *) {
            return device.maxAvailableVideoZoomFactor
        } else {
            return device.activeFormat.videoMaxZoomFactor
        }
    }
    
    func setVideoZoomFactor(_ zoomFactor: CGFloat) {
        guard let device = videoInput?.device else {
            return
        }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = zoomFactor
            device.unlockForConfiguration()
        } catch {
            print("调整焦距失败 \(error.localizedDescription)")
        }
    }
    
    
    func focusCamera(mode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode, point: CGPoint) {
        do {
            guard let device = videoInput?.device else {
                return
            }
            
            try device.lockForConfiguration()
            
            if device.isFocusModeSupported(mode) {
                device.focusMode = mode
            }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
            }
            if device.isExposureModeSupported(exposureMode) {
                device.exposureMode = exposureMode
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
            }
            
            device.unlockForConfiguration()
        } catch {
            print("相机聚焦设置失败 \(error.localizedDescription)")
        }
    }
    
    func startRecord() {
        guard !movieFileOutput.isRecording else {
            return
        }
        dismissBtn.isHidden = true
        let connection = movieFileOutput.connection(with: .video)
        connection?.videoScaleAndCropFactor = 1
        if !restartRecordAfterSwitchCamera {
            connection?.videoOrientation = orientation
            cacheVideoOrientation = orientation
        } else {
            connection?.videoOrientation = cacheVideoOrientation
        }
        // 解决前置摄像头录制视频时候左右颠倒的问题
        if videoInput?.device.position == .front, connection?.isVideoMirroringSupported == true {
            // 镜像设置
            connection?.isVideoMirrored = true
        }
        let url = URL(fileURLWithPath: PBVideoManager.getVideoExportFilePath())
        movieFileOutput.startRecording(to: url, recordingDelegate: self)
    }
    
    func finishRecord() {
        guard movieFileOutput.isRecording else {
            return
        }
        movieFileOutput.stopRecording()
        stopRecordAnimation()
    }
    
    func startRecordAnimation() {
        UIView.animate(withDuration: 0.1, animations: {
            self.largeCircleView.layer.transform = CATransform3DScale(CATransform3DIdentity, PBCustomCamera.Layout.largeCircleRecordScale, PBCustomCamera.Layout.largeCircleRecordScale, 1)
            self.smallCircleView.layer.transform = CATransform3DScale(CATransform3DIdentity, PBCustomCamera.Layout.smallCircleRecordScale, PBCustomCamera.Layout.smallCircleRecordScale, 1)
        }) { (_) in
            self.largeCircleView.layer.addSublayer(self.animateLayer)
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = 0
            animation.toValue = 1
            animation.duration = Double(PhotoConfiguration.default().maxRecordDuration)
            animation.delegate = self
            self.animateLayer.add(animation, forKey: nil)
        }
    }
    
    func stopRecordAnimation() {
        animateLayer.removeFromSuperlayer()
        animateLayer.removeAllAnimations()
        largeCircleView.transform = .identity
        smallCircleView.transform = .identity
    }
    
    public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        finishRecord()
    }
    
    func resetSubViewStatus() {
        if session.isRunning {
            showTipsLabel(animate: true)
            bottomView.isHidden = false
            dismissBtn.isHidden = false
            switchCameraBtn.isHidden = false
            retakeBtn.isHidden = true
            editBtn.isHidden = true
            doneBtn.isHidden = true
            takedImageView.isHidden = true
            takedImage = nil
        } else {
            hideTipsLabel(animate: false)
            bottomView.isHidden = true
            dismissBtn.isHidden = true
            switchCameraBtn.isHidden = true
            retakeBtn.isHidden = false
            if PhotoConfiguration.default().allowEditImage {
                editBtn.isHidden = takedImage == nil
            }
            doneBtn.isHidden = false
        }
    }
    
    func playRecordVideo(fileUrl: URL) {
        recordVideoPlayerLayer?.isHidden = false
        let player = AVPlayer(url: fileUrl)
        player.automaticallyWaitsToMinimizeStalling = false
        recordVideoPlayerLayer?.player = player
        player.play()
    }
    
    @objc func recordVideoPlayFinished() {
        recordVideoPlayerLayer?.player?.seek(to: .zero)
        recordVideoPlayerLayer?.player?.play()
    }

}


extension PBCustomCamera: AVCapturePhotoCaptureDelegate {
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if photoSampleBuffer == nil || error != nil {
            print("拍照失败 \(error?.localizedDescription ?? "")")
            return
        }
        
        if let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer!, previewPhotoSampleBuffer: previewPhotoSampleBuffer) {
            session.stopRunning()
            takedImage = UIImage(data: data)?.fixOrientation()
            takedImageView.image = takedImage
            takedImageView.isHidden = false
            resetSubViewStatus()
        } else {
            print("拍照失败，data为空")
        }
    }
    
}


extension PBCustomCamera: AVCaptureFileOutputRecordingDelegate {
    
    public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        if restartRecordAfterSwitchCamera {
            restartRecordAfterSwitchCamera = false
            // 稍微加一个延时，否则切换摄像头后拍摄时间会略小于设置的最大值
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let pauseTime = self.animateLayer.timeOffset
                self.animateLayer.speed = 1
                self.animateLayer.timeOffset = 0
                self.animateLayer.beginTime = 0
                let timeSincePause = self.animateLayer.convertTime(CACurrentMediaTime(), from: nil) - pauseTime
                self.animateLayer.beginTime = timeSincePause
            }
        } else {
            startRecordAnimation()
        }
    }
    
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if restartRecordAfterSwitchCamera {
            recordUrls.append(outputFileURL)
            startRecord()
            return
        }
        recordUrls.append(outputFileURL)
        
        var duration: Double = 0
        if recordUrls.count == 1 {
            duration = output.recordedDuration.seconds
        } else {
            for url in recordUrls {
                let temp = AVAsset(url: url)
                duration += temp.duration.seconds
            }
        }
        
        // 重置焦距
        setVideoZoomFactor(1)
        if duration < Double(PhotoConfiguration.default().minRecordDuration) {
            showAlertView(String(format: "至少录制\(PhotoConfiguration.default().minRecordDuration)秒" ), self)
            resetSubViewStatus()
            recordUrls.forEach { try? FileManager.default.removeItem(at: $0) }
            recordUrls.removeAll()
            return
        }
        
        // 拼接视频
        session.stopRunning()
        resetSubViewStatus()
        if recordUrls.count > 1 {
            PBVideoManager.mergeVideos(fileUrls: recordUrls) { [weak self] (url, error) in
                if let url = url, error == nil {
                    self?.videoUrl = url
                    self?.playRecordVideo(fileUrl: url)
                } else if let error = error {
                    self?.videoUrl = nil
                    showAlertView(error.localizedDescription, self)
                }

                self?.recordUrls.forEach { try? FileManager.default.removeItem(at: $0) }
                self?.recordUrls.removeAll()
            }
        } else {
            videoUrl = outputFileURL
            playRecordVideo(fileUrl: outputFileURL)
            recordUrls.removeAll()
        }
    }
    
}


extension PBCustomCamera: UIGestureRecognizerDelegate {
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        if gestureRecognizer is UILongPressGestureRecognizer, otherGestureRecognizer is UIPanGestureRecognizer {
//            return true
//        }
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer is UIPanGestureRecognizer, touch.view is UIControl {
            // 解决拖动改变焦距时，无法点击其他按钮的问题
            return false
        }
        return true
    }
    
}


public extension PBCustomCamera {
    
    enum CaptureSessionPreset: Int {
        
        var avSessionPreset: AVCaptureSession.Preset {
            switch self {
            case .cif352x288:
                return .cif352x288
            case .vga640x480:
                return .vga640x480
            case .hd1280x720:
                return .hd1280x720
            case .hd1920x1080:
                return .hd1920x1080
            case .hd4K3840x2160:
                return .hd4K3840x2160
            }
        }
        
        case cif352x288
        case vga640x480
        case hd1280x720
        case hd1920x1080
        case hd4K3840x2160
    }
    
    enum CameraFlashMode: Int  {
        
        // 转自定义相机
        var avFlashMode: AVCaptureDevice.FlashMode {
            switch self {
            case .auto:
                return .auto
            case .on:
                return .on
            case .off:
                return .off
            }
        }
        
        // 转系统相机
        var imagePickerFlashMode: UIImagePickerController.CameraFlashMode {
            switch self {
            case .auto:
                return .auto
            case .on:
                return .on
            case .off:
                return .off
            }
        }
        
        case auto
        case on
        case off
    }
    
    enum VideoExportType: Int {
        
        var format: String {
            switch self {
            case .mov:
                return "mov"
            case .mp4:
                return "mp4"
            }
        }
        
        var avFileType: AVFileType {
            switch self {
            case .mov:
                return .mov
            case .mp4:
                return .mp4
            }
        }
        
        case mov
        case mp4
    }
    
}
