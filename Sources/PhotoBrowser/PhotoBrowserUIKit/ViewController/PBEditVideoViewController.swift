//
//  PBEditVideoViewController.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit
import Photos

public class PBEditVideoViewController: UIViewController {

    static let frameImageSize = CGSize(width: 50.0 * 2.0 / 3.0, height: 50.0)
    
    let avAsset: AVAsset
    
    let animateDismiss: Bool
    
    var cancelBtn: UIButton!
    
    var doneBtn: UIButton!
    
    var timer: Timer?
    
    var playerLayer: AVPlayerLayer!
    
    var collectionView: UICollectionView!
    
    var frameImageBorderView: PBEditVideoFrameImageBorderView!
    
    var leftSideView: UIImageView!
    
    var rightSideView: UIImageView!
    
    var leftSidePan: UIPanGestureRecognizer!
    
    var rightSidePan: UIPanGestureRecognizer!
    
    var indicator: UIView!
    
    var measureCount = 0
    
    lazy var interval: TimeInterval = {
        let assetDuration = round(avAsset.duration.seconds)
        return min(assetDuration, TimeInterval(PhotoConfiguration.default().maxEditVideoTime)) / 10
    }()
    
    var requestFrameImageQueue: OperationQueue!
    
    var avAssetRequestID = PHInvalidImageRequestID
    
    var videoRequestID = PHInvalidImageRequestID
    
    var frameImageCache: [Int: UIImage] = [:]
    
    var requestFailedFrameImageIndex: [Int] = []
    
    var shouldLayout = true
    
    lazy var generator: AVAssetImageGenerator = {
        let g = AVAssetImageGenerator(asset: avAsset)
        g.maximumSize = CGSize(width: PBEditVideoViewController.frameImageSize.width * 3, height: PBEditVideoViewController.frameImageSize.height * 3)
        g.appliesPreferredTrackTransform = true
        g.requestedTimeToleranceBefore = .zero
        g.requestedTimeToleranceAfter = .zero
        g.apertureMode = .productionAperture
        return g
    }()
    
    @objc public var editFinishBlock: ( (URL?) -> Void )?
    
    public override var prefersStatusBarHidden: Bool {
        return true
    }
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    deinit {
        cleanTimer()
        requestFrameImageQueue.cancelAllOperations()
        if avAssetRequestID > PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(avAssetRequestID)
        }
        if videoRequestID > PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(videoRequestID)
        }
    }
    
    
    /// initialize
    /// - Parameters:
    ///   - avAsset: AVAsset对象，需要传入本地视频，网络视频不支持
    ///   - animateDismiss: 退出界面时是否显示dismiss动画
    @objc public init(avAsset: AVAsset, animateDismiss: Bool = false) {
        self.avAsset = avAsset
        self.animateDismiss = animateDismiss
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        
        requestFrameImageQueue = OperationQueue()
        requestFrameImageQueue.maxConcurrentOperationCount = 10
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        analysisAssetImages()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard shouldLayout else {
            return
        }
        shouldLayout = false
        
        var insets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        if #available(iOS 11.0, *) {
            insets = view.safeAreaInsets
        }
        
        let btnH = PBLayout.bottomToolBtnH
        let bottomBtnAndColSpacing: CGFloat = 20
        let playerLayerY = insets.top + 20
        let diffBottom = btnH + PBEditVideoViewController.frameImageSize.height + bottomBtnAndColSpacing + insets.bottom + 30
        
        playerLayer.frame = CGRect(x: 15, y: insets.top + 20, width: view.bounds.width - 30, height: view.bounds.height - playerLayerY - diffBottom)
        
        let cancelBtnW: CGFloat = 40.0
        cancelBtn.frame = CGRect(x: 20, y: view.bounds.height - insets.bottom - btnH, width: cancelBtnW, height: btnH)
        let doneBtnW: CGFloat = 40.0
        doneBtn.frame = CGRect(x: view.bounds.width-doneBtnW-20, y: view.bounds.height - insets.bottom - btnH, width: doneBtnW, height: btnH)
        
        collectionView.frame = CGRect(x: 0, y: doneBtn.frame.minY - bottomBtnAndColSpacing - PBEditVideoViewController.frameImageSize.height, width: view.bounds.width, height: PBEditVideoViewController.frameImageSize.height)
        
        let frameViewW = PBEditVideoViewController.frameImageSize.width * 10
        frameImageBorderView.frame = CGRect(x: (view.bounds.width - frameViewW)/2, y: collectionView.frame.minY, width: frameViewW, height: PBEditVideoViewController.frameImageSize.height)
        // 左右拖动view
        let leftRightSideViewW = PBEditVideoViewController.frameImageSize.width/2
        leftSideView.frame = CGRect(x: frameImageBorderView.frame.minX, y: collectionView.frame.minY, width: leftRightSideViewW, height: PBEditVideoViewController.frameImageSize.height)
        let rightSideViewX = view.bounds.width - frameImageBorderView.frame.minX - leftRightSideViewW
        rightSideView.frame = CGRect(x: rightSideViewX, y: collectionView.frame.minY, width: leftRightSideViewW, height: PBEditVideoViewController.frameImageSize.height)
        
        frameImageBorderView.validRect = frameImageBorderView.convert(clipRect(), from: view)
    }
    
    func setupUI() {
        view.backgroundColor = .black
        
        playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = PBEditVideoViewController.frameImageSize
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.scrollDirection = .horizontal
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        view.addSubview(collectionView)
        
        PBEditVideoFrameImageCell.pb_register(collectionView)
        
        frameImageBorderView = PBEditVideoFrameImageBorderView()
        frameImageBorderView.isUserInteractionEnabled = false
        view.addSubview(frameImageBorderView)
        
        indicator = UIView()
        indicator.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        view.addSubview(indicator)
        
        leftSideView = UIImageView(image: getImage("pb_ic_left"))
        leftSideView.isUserInteractionEnabled = true
        view.addSubview(leftSideView)
        
        leftSidePan = UIPanGestureRecognizer(target: self, action: #selector(leftSidePanAction(_:)))
        leftSidePan.delegate = self
        view.addGestureRecognizer(leftSidePan)
        
        rightSideView = UIImageView(image: getImage("pb_ic_right"))
        rightSideView.isUserInteractionEnabled = true
        view.addSubview(rightSideView)
        
        rightSidePan = UIPanGestureRecognizer(target: self, action: #selector(rightSidePanAction(_:)))
        rightSidePan.delegate = self
        view.addGestureRecognizer(rightSidePan)
        
        collectionView.panGestureRecognizer.require(toFail: leftSidePan)
        collectionView.panGestureRecognizer.require(toFail: rightSidePan)
        rightSidePan.require(toFail: leftSidePan)
        
        cancelBtn = UIButton(type: .custom)
        cancelBtn.setTitle("取消", for: .normal)
        cancelBtn.setTitleColor(.bottomToolViewBtnNormalTitleColor, for: .normal)
        cancelBtn.titleLabel?.font = PBLayout.bottomToolTitleFont
        cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        view.addSubview(cancelBtn)
        
        doneBtn = UIButton(type: .custom)
        doneBtn.setTitle("完成", for: .normal)
        doneBtn.setTitleColor(.bottomToolViewBtnNormalTitleColor, for: .normal)
        doneBtn.titleLabel?.font = PBLayout.bottomToolTitleFont
        doneBtn.addTarget(self, action: #selector(doneBtnClick), for: .touchUpInside)
        doneBtn.backgroundColor = .bottomToolViewBtnNormalBgColor
        doneBtn.layer.masksToBounds = true
        doneBtn.layer.cornerRadius = PBLayout.bottomToolBtnCornerRadius
        view.addSubview(doneBtn)
    }
    
    @objc func cancelBtnClick() {
        cleanTimer()
        dismiss(animated: animateDismiss, completion: nil)
    }
    
    @objc func doneBtnClick() {
        cleanTimer()
        
        let d = CGFloat(interval) * clipRect().width / PBEditVideoViewController.frameImageSize.width
        if Int(round(d)) < PhotoConfiguration.default().minSelectVideoDuration {
            let message = String(format: "不能选择低于%ld秒的视频", PhotoConfiguration.default().minSelectVideoDuration)
            showAlertView(message, self)
            return
        }
        if Int(round(d)) > PhotoConfiguration.default().maxSelectVideoDuration {
            let message = String(format: "不能选择超过%ld秒的视频", PhotoConfiguration.default().maxSelectVideoDuration)
            showAlertView(message, self)
            return
        }
        
        if d == round(CGFloat(avAsset.duration.seconds)) {
            dismiss(animated: animateDismiss) {
                self.editFinishBlock?(nil)
            }
            return
        }
        
        let hud = PBProgressHUD(style: PhotoConfiguration.default().hudStyle)
        hud.show()
        
        PBVideoManager.exportEditVideo(for: avAsset, range: getTimeRange()) { [weak self] (url, error) in
            hud.hide()
            if let er = error {
                showAlertView(er.localizedDescription, self)
            } else if url != nil {
                self?.dismiss(animated: self?.animateDismiss ?? false) {
                    self?.editFinishBlock?(url)
                }
            }
        }
    }
    
    @objc func leftSidePanAction(_ pan: UIPanGestureRecognizer) {
        let point = pan.location(in: view)
        
        if pan.state == .began {
            frameImageBorderView.layer.borderColor = UIColor(white: 1, alpha: 0.4).cgColor
            cleanTimer()
        } else if pan.state == .changed {
            let minX = frameImageBorderView.frame.minX
            let maxX = rightSideView.frame.minX - leftSideView.frame.width
            
            var frame = leftSideView.frame
            frame.origin.x = min(maxX, max(minX, point.x))
            leftSideView.frame = frame
            frameImageBorderView.validRect = frameImageBorderView.convert(clipRect(), from: view)
            
            playerLayer.player?.seek(to: getStartTime(), toleranceBefore: .zero, toleranceAfter: .zero)
        } else if pan.state == .ended || pan.state == .cancelled {
            frameImageBorderView.layer.borderColor = UIColor.clear.cgColor
            startTimer()
        }
    }
    
    @objc func rightSidePanAction(_ pan: UIPanGestureRecognizer) {
        let point = pan.location(in: view)
        
        if pan.state == .began {
            frameImageBorderView.layer.borderColor = UIColor(white: 1, alpha: 0.4).cgColor
            cleanTimer()
        } else if pan.state == .changed {
            let minX = leftSideView.frame.maxX
            let maxX = frameImageBorderView.frame.maxX - rightSideView.frame.width
            
            var frame = rightSideView.frame
            frame.origin.x = min(maxX, max(minX, point.x))
            rightSideView.frame = frame
            frameImageBorderView.validRect = frameImageBorderView.convert(clipRect(), from: view)
            
            playerLayer.player?.seek(to: getStartTime(), toleranceBefore: .zero, toleranceAfter: .zero)
        } else if pan.state == .ended || pan.state == .cancelled {
            frameImageBorderView.layer.borderColor = UIColor.clear.cgColor
            startTimer()
        }
    }
    
    @objc func appWillResignActive() {
        cleanTimer()
        indicator.layer.removeAllAnimations()
    }
    
    @objc func appDidBecomeActive() {
        startTimer()
    }
    
    func analysisAssetImages() {
        let duration = round(avAsset.duration.seconds)
        guard duration > 0 else {
            showFetchFailedAlert()
            return
        }
        let item = AVPlayerItem(asset: avAsset)
        let player = AVPlayer(playerItem: item)
        playerLayer.player = player
        startTimer()
        
        measureCount = Int(duration / interval)
        collectionView.reloadData()
        requestVideoMeasureFrameImage()
    }
    
    func requestVideoMeasureFrameImage() {
        for i in 0..<measureCount {
            let mes = TimeInterval(i) * interval
            let time = CMTimeMakeWithSeconds(Float64(mes), preferredTimescale: avAsset.duration.timescale)
            
            let operation = PBEditVideoFetchFrameImageOperation(generator: generator, time: time) { [weak self] (image, time) in
                self?.frameImageCache[Int(i)] = image
                let cell = self?.collectionView.cellForItem(at: IndexPath(row: Int(i), section: 0)) as? PBEditVideoFrameImageCell
                cell?.imageView.image = image
                if image == nil {
                    self?.requestFailedFrameImageIndex.append(i)
                }
            }
            requestFrameImageQueue.addOperation(operation)
        }
    }
    
    func startTimer() {
        cleanTimer()
        let duration = interval * TimeInterval(clipRect().width / PBEditVideoViewController.frameImageSize.width)
        
        timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: true, block: { (_) in
            self.playerLayer.player?.seek(to: self.getStartTime(), toleranceBefore: .zero, toleranceAfter: .zero)
            if (self.playerLayer.player?.rate ?? 0) == 0 {
                self.playerLayer.player?.play()
            }
        })
        
        timer?.fire()
        RunLoop.main.add(timer!, forMode: .common)
        
        indicator.isHidden = false
        indicator.frame = CGRect(x: leftSideView.frame.minX, y: leftSideView.frame.minY, width: 2, height: leftSideView.frame.height)
        indicator.layer.removeAllAnimations()
        
        UIView.animate(withDuration: duration, delay: 0, options: [.allowUserInteraction, .curveLinear, .repeat], animations: {
            self.indicator.frame = CGRect(x: self.rightSideView.frame.maxX-2, y: self.rightSideView.frame.minY, width: 2, height: self.rightSideView.frame.height)
        }, completion: nil)
    }
    
    func cleanTimer() {
        timer?.invalidate()
        timer = nil
        indicator.layer.removeAllAnimations()
        indicator.isHidden = true
        playerLayer.player?.pause()
    }
    
    func getStartTime() -> CMTime {
        var rect = collectionView.convert(clipRect(), from: view)
        rect.origin.x -= frameImageBorderView.frame.minX
        let second = max(0, CGFloat(interval) * rect.minX / PBEditVideoViewController.frameImageSize.width)
        return CMTimeMakeWithSeconds(Float64(second), preferredTimescale: avAsset.duration.timescale)
    }
    
    func getTimeRange() -> CMTimeRange {
        let start = getStartTime()
        let d = CGFloat(interval) * clipRect().width / PBEditVideoViewController.frameImageSize.width
        let duration = CMTimeMakeWithSeconds(Float64(d), preferredTimescale: avAsset.duration.timescale)
        return CMTimeRangeMake(start: start, duration: duration)
    }
    
    func clipRect() -> CGRect {
        var frame = CGRect.zero
        frame.origin.x = leftSideView.frame.minX
        frame.origin.y = leftSideView.frame.minY
        frame.size.width = rightSideView.frame.maxX - frame.minX
        frame.size.height = leftSideView.frame.height
        return frame
    }
    
    func showFetchFailedAlert() {
        let alert = UIAlertController(title: nil, message: "iCloud无法同步", preferredStyle: .alert)
        let action = UIAlertAction(title: "确定", style: .default) { (_) in
            self.dismiss(animated: false, completion: nil)
        }
        alert.addAction(action)
        showDetailViewController(alert, sender: nil)
    }
    
}


extension PBEditVideoViewController: UIGestureRecognizerDelegate {
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == leftSidePan {
            let point = gestureRecognizer.location(in: view)
            let frame = leftSideView.frame
            let outerFrame = frame.inset(by: UIEdgeInsets(top: -20, left: -40, bottom: -20, right: -20))
            return outerFrame.contains(point)
        } else if gestureRecognizer == rightSidePan {
            let point = gestureRecognizer.location(in: view)
            let frame = rightSideView.frame
            let outerFrame = frame.inset(by: UIEdgeInsets(top: -20, left: -20, bottom: -20, right: -40))
            return outerFrame.contains(point)
        }
        return true
    }
    
}


extension PBEditVideoViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        cleanTimer()
        playerLayer.player?.seek(to: getStartTime(), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            startTimer()
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        startTimer()
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let w = PBEditVideoViewController.frameImageSize.width * 10
        let leftRight = (collectionView.frame.width - w) / 2
        return UIEdgeInsets(top: 0, left: leftRight, bottom: 0, right: leftRight)
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return measureCount
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PBEditVideoFrameImageCell.pb_identifier(), for: indexPath) as! PBEditVideoFrameImageCell
        
        if let image = frameImageCache[indexPath.row] {
            cell.imageView.image = image
        }
        
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if requestFailedFrameImageIndex.contains(indexPath.row) {
            let mes = TimeInterval(indexPath.row) * interval
            let time = CMTimeMakeWithSeconds(Float64(mes), preferredTimescale: avAsset.duration.timescale)
            
            let operation = PBEditVideoFetchFrameImageOperation(generator: generator, time: time) { [weak self] (image, time) in
                self?.frameImageCache[indexPath.row] = image
                let cell = self?.collectionView.cellForItem(at: IndexPath(row: indexPath.row, section: 0)) as? PBEditVideoFrameImageCell
                cell?.imageView.image = image
                if image != nil {
                    self?.requestFailedFrameImageIndex.removeAll { $0 == indexPath.row }
                }
            }
            requestFrameImageQueue.addOperation(operation)
        }
    }
    
}


class PBEditVideoFrameImageBorderView: UIView {
    
    var validRect: CGRect = .zero {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.borderWidth = 2
        layer.borderColor = UIColor.clear.cgColor
        backgroundColor = .clear
        isOpaque = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(UIColor.white.cgColor)
        context?.setLineWidth(4)
        
        context?.move(to: CGPoint(x: validRect.minX, y: 0))
        context?.addLine(to: CGPoint(x: validRect.minX+validRect.width, y: 0))
        
        context?.move(to: CGPoint(x: validRect.minX, y: rect.height))
        context?.addLine(to: CGPoint(x: validRect.minX+validRect.width, y: rect.height))
        
        context?.strokePath()
    }
    
}


class PBEditVideoFrameImageCell: UICollectionViewCell {
    
    var imageView: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }
    
}


class PBEditVideoFetchFrameImageOperation: Operation {

    let generator: AVAssetImageGenerator
    
    let time: CMTime
    
    let completion: ( (UIImage?, CMTime) -> Void )
    
    var pri_isExecuting = false {
        willSet {
            willChangeValue(forKey: "isExecuting")
        }
        didSet {
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    override var isExecuting: Bool {
        return pri_isExecuting
    }
    
    var pri_isFinished = false {
        willSet {
            willChangeValue(forKey: "isFinished")
        }
        didSet {
            didChangeValue(forKey: "isFinished")
        }
    }
    
    override var isFinished: Bool {
        return pri_isFinished
    }
    
    var pri_isCancelled = false {
        willSet {
            willChangeValue(forKey: "isCancelled")
        }
        didSet {
            didChangeValue(forKey: "isCancelled")
        }
    }

    override var isCancelled: Bool {
        return pri_isCancelled
    }
    
    init(generator: AVAssetImageGenerator, time: CMTime, completion: @escaping ( (UIImage?, CMTime) -> Void )) {
        self.generator = generator
        self.time = time
        self.completion = completion
        super.init()
    }
    
    override func start() {
        if isCancelled {
            fetchFinish()
            return
        }
        pri_isExecuting = true
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { (_, cgImage, _, result, error) in
            if result == .succeeded, let cg = cgImage {
                let image = UIImage(cgImage: cg)
                DispatchQueue.main.async {
                    self.completion(image, self.time)
                }
                self.fetchFinish()
            } else {
                self.fetchFinish()
            }
        }
    }
    
    func fetchFinish() {
        pri_isExecuting = false
        pri_isFinished = true
    }
    
    override func cancel() {
        super.cancel()
        pri_isCancelled = true
    }
    
}
