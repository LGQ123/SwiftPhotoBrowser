//
//  PBPreviewBaseCell.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit
import Photos
import PhotosUI
import PhotoLib
class PBPreviewBaseCell: UICollectionViewCell {
    
    var singleTapBlock: ( () -> Void )?
    
    var currentImage: UIImage? {
        return nil
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        NotificationCenter.default.addObserver(self, selector: #selector(previewVCScroll), name: PBPhotoPreviewController.previewVCScrollNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func previewVCScroll() {
        
    }
    
    func resetSubViewStatusWhenCellEndDisplay() {
        
    }
    
    func resizeImageView(imageView: UIImageView, asset: PHAsset) {
        let size = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
        var frame: CGRect = .zero
        
        let viewW = bounds.width
        let viewH = bounds.height
        
        var width = viewW
        
        // video和livephoto没必要处理长图和宽图
        if isLandscape() {
            let height = viewH
            frame.size.height = height
            
            let imageWHRatio = size.width / size.height
            let viewWHRatio = viewW / viewH
            
            if imageWHRatio > viewWHRatio {
                frame.size.width = floor(height * imageWHRatio)
                if frame.size.width > viewW {
                    frame.size.width = viewW
                    frame.size.height = viewW / imageWHRatio
                }
            } else {
                width = floor(height * imageWHRatio)
                if width < 1 || width.isNaN {
                    width = viewW
                }
                frame.size.width = width
            }
        } else {
            frame.size.width = width
            
            let imageHWRatio = size.height / size.width
            let viewHWRatio = viewH / viewW
            
            if imageHWRatio > viewHWRatio {
                frame.size.height = floor(width * imageHWRatio)
            } else {
                var height = floor(width * imageHWRatio)
                if height < 1 || height.isNaN {
                    height = viewH
                }
                frame.size.height = height
            }
        }
        
        imageView.frame = frame
        
        if isLandscape() {
            if frame.height < viewH {
                imageView.center = CGPoint(x: viewW / 2, y: viewH / 2)
            } else {
                imageView.frame = CGRect(origin: CGPoint(x: (viewW-frame.width)/2, y: 0), size: frame.size)
            }
        } else {
            if frame.width < viewW || frame.height < viewH {
                imageView.center = CGPoint(x: viewW / 2, y: viewH / 2)
            }
        }
    }
    
    func animateImageFrame(convertTo view: UIView) -> CGRect {
        return .zero
    }
    
}


// MARK: local and net image preview cell
class PBLocalImagePreviewCell: PBPreviewBaseCell {
    
    override var currentImage: UIImage? {
        return preview.image
    }
    
    var preview: PBPreviewView!
    
    var image: UIImage? = nil {
        didSet {
            preview.imageView.image = image
            preview.resetSubViewSize()
        }
    }
    
    var longPressBlock: ( () -> Void )?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        preview.frame = bounds
    }
    
    private func setupUI() {
        preview = PBPreviewView()
        preview.singleTapBlock = { [weak self] in
            self?.singleTapBlock?()
        }
        contentView.addSubview(preview)
        
        let longGes = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
        longGes.minimumPressDuration = 0.5
        addGestureRecognizer(longGes)
    }
    
    override func resetSubViewStatusWhenCellEndDisplay() {
        preview.scrollView.zoomScale = 1
    }
    
    @objc func longPressAction(_ ges: UILongPressGestureRecognizer) {
        guard let _ = currentImage else {
            return
        }
        
        if ges.state == .began {
            longPressBlock?()
        }
    }
    
}


// MARK: net image preview cell
class PBNetImagePreviewCell: PBLocalImagePreviewCell {
    
    var progressView: PBProgressView!
    
    var progress: CGFloat = 0 {
        didSet {
            progressView.progress = progress
            progressView.isHidden = progress >= 1
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        progressView = PBProgressView()
        progressView.isHidden = true
        contentView.addSubview(progressView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        bringSubviewToFront(progressView)
        progressView.frame = CGRect(x: bounds.width / 2 - 20, y: bounds.height / 2 - 20, width: 40, height: 40)
    }
    
    override func resetSubViewStatusWhenCellEndDisplay() {
        progressView.isHidden = true
    }
    
}


// MARK: static image preview cell
class PBPhotoPreviewCell: PBPreviewBaseCell {
    
    override var currentImage: UIImage? {
        return preview.image
    }
    
    var preview: PBPreviewView!
    
    var model: PBPhotoModel! {
        didSet {
            preview.model = model
        }
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
        preview.frame = bounds
    }
    
    private func setupUI() {
        preview = PBPreviewView()
        preview.singleTapBlock = { [weak self] in
            self?.singleTapBlock?()
        }
        contentView.addSubview(preview)
    }
    
    override func resetSubViewStatusWhenCellEndDisplay() {
        preview.scrollView.zoomScale = 1
    }
    
    override func animateImageFrame(convertTo view: UIView) -> CGRect {
        let r1 = preview.scrollView.convert(preview.containerView.frame, to: self)
        return convert(r1, to: view)
    }
    
}


// MARK: gif preview cell
class PBGifPreviewCell: PBPreviewBaseCell {
    
    override var currentImage: UIImage? {
        return preview.image
    }
    
    var preview: PBPreviewView!
    
    var model: PBPhotoModel! {
        didSet {
            preview.model = model
        }
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
        preview.frame = bounds
    }
    
    private func setupUI() {
        preview = PBPreviewView()
        preview.singleTapBlock = { [weak self] in
            self?.singleTapBlock?()
        }
        contentView.addSubview(preview)
    }
    
    override func previewVCScroll() {
        preview.pauseGif()
    }
    
    func resumeGif() {
        preview.resumeGif()
    }
    
    func pauseGif() {
        preview.pauseGif()
    }
    
    /// gif图加载会导致主线程卡顿一下，所以放在willdisplay时候加载
    func loadGifWhenCellDisplaying() {
        preview.loadGifData()
    }
    
    override func resetSubViewStatusWhenCellEndDisplay() {
        preview.scrollView.zoomScale = 1
    }
    
    override func animateImageFrame(convertTo view: UIView) -> CGRect {
        let r1 = preview.scrollView.convert(preview.containerView.frame, to: self)
        return convert(r1, to: view)
    }
    
}


// MARK: live photo preview cell
class PBLivePhotoPewviewCell: PBPreviewBaseCell {
    
    override var currentImage: UIImage? {
        return imageView.image
    }
    
    var livePhotoView: PHLivePhotoView!
    
    var imageView: UIImageView!
    
    var imageRequestID: PHImageRequestID = PHInvalidImageRequestID
    
    var livePhotoRequestID: PHImageRequestID = PHInvalidImageRequestID
    
    var onFetchingLivePhoto = false
    
    var fetchLivePhotoDone = false
    
    var model: PBPhotoModel! {
        didSet {
            loadNormalImage()
        }
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
        livePhotoView.frame = bounds
        resizeImageView(imageView: imageView, asset: model.asset)
    }
    
    private func setupUI() {
        livePhotoView = PHLivePhotoView()
        livePhotoView.contentMode = .scaleAspectFit
        contentView.addSubview(livePhotoView)
        
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        contentView.addSubview(imageView)
    }
    
    override func previewVCScroll() {
        livePhotoView.stopPlayback()
    }
    
    func loadNormalImage() {
        if imageRequestID > PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(imageRequestID)
        }
        if livePhotoRequestID > PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(livePhotoRequestID)
        }
        onFetchingLivePhoto = false
        imageView.isHidden = false
        
        // livephoto 加载个较小的预览图即可
        var size = model.previewSize
        size.width /= 4
        size.height /= 4
        
        resizeImageView(imageView: imageView, asset: model.asset)
        imageRequestID = PBPhotoManager.fetchImage(for: model.asset, size: size, completion: { [weak self] (image, isDegread) in
            self?.imageView.image = image
        })
    }
    
    func loadLivePhotoData() {
        guard !onFetchingLivePhoto else {
            if fetchLivePhotoDone {
                startPlayLivePhoto()
            }
            return
        }
        onFetchingLivePhoto = true
        fetchLivePhotoDone = false
        
        livePhotoRequestID = PBPhotoManager.fetchLivePhoto(for: model.asset, completion: { (livePhoto, info, isDegraded) in
            if !isDegraded {
                self.fetchLivePhotoDone = true
                self.livePhotoView.livePhoto = livePhoto
                self.startPlayLivePhoto()
            }
        })
    }
    
    func startPlayLivePhoto() {
        imageView.isHidden = true
        livePhotoView.startPlayback(with: .full)
    }
    
    override func animateImageFrame(convertTo view: UIView) -> CGRect {
        return convert(imageView.frame, to: view)
    }
    
}


// MARK: video preview cell
class PBVideoPreviewCell: PBPreviewBaseCell {
    
    override var currentImage: UIImage? {
        return imageView.image
    }
    
    var player: AVPlayer?
    
    var playerLayer: AVPlayerLayer?
    
    var progressView: PBProgressView!
    
    var imageView: UIImageView!
    
    var playBtn: UIButton!
    
    var syncErrorLabel: UILabel!
    
    var imageRequestID: PHImageRequestID = PHInvalidImageRequestID
    
    var videoRequestID: PHImageRequestID = PHInvalidImageRequestID
    
    var onFetchingVideo = false
    
    var fetchVideoDone = false
    
    var isPlaying: Bool {
        if player != nil, player?.rate != 0 {
            return true
        }
        return false
    }
    
    var model: PBPhotoModel! {
        didSet {
            configureCell()
        }
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
        playerLayer?.frame = bounds
        resizeImageView(imageView: imageView, asset: model.asset)
        let insets = deviceSafeAreaInsets()
        playBtn.frame = CGRect(x: 0, y: insets.top, width: bounds.width, height: bounds.height - insets.top - insets.bottom)
        syncErrorLabel.frame = CGRect(x: 10, y: insets.top + 60, width: bounds.width - 20, height: 35)
        progressView.frame = CGRect(x: bounds.width / 2 - 30, y: bounds.height / 2 - 30, width: 60, height: 60)
    }
    
    private func setupUI() {
        imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        contentView.addSubview(imageView)
        
        let attStr = NSMutableAttributedString()
        let attach = NSTextAttachment()
        attach.image = getImage("pb_videoLoadFailed")
        attach.bounds = CGRect(x: 0, y: -10, width: 30, height: 30)
        attStr.append(NSAttributedString(attachment: attach))
        let errorText = NSAttributedString(string: "iCloud无法同步", attributes: [NSAttributedString.Key.foregroundColor: UIColor.white, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12)])
        attStr.append(errorText)
        syncErrorLabel = UILabel()
        syncErrorLabel.attributedText = attStr
        contentView.addSubview(syncErrorLabel)
        
        progressView = PBProgressView()
        contentView.addSubview(progressView)
        
        playBtn = UIButton(type: .custom)
        playBtn.setImage(getImage("pb_playVideo"), for: .normal)
        playBtn.addTarget(self, action: #selector(playBtnClick), for: .touchUpInside)
        contentView.addSubview(playBtn)
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    func configureCell() {
        imageView.image = nil
        imageView.isHidden = false
        syncErrorLabel.isHidden = true
        playBtn.isEnabled = false
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        
        if imageRequestID > PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(imageRequestID)
        }
        if videoRequestID > PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(videoRequestID)
        }
        
        // 视频预览图尺寸
        var size = model.previewSize
        size.width /= 2
        size.height /= 2
        
        resizeImageView(imageView: imageView, asset: model.asset)
        imageRequestID = PBPhotoManager.fetchImage(for: model.asset, size: size, completion: { (image, isDegraded) in
            self.imageView.image = image
        })
        
        videoRequestID = PBPhotoManager.fetchVideo(for: model.asset, progress: { [weak self] (progress, _, _, _) in
            self?.progressView.progress = CGFloat(progress)
            if progress >= 1 {
                self?.progressView.isHidden = true
            } else {
                self?.progressView.isHidden = false
            }
        }, completion: { [weak self] (item, info, isDegraded) in
            let error = info?[PHImageErrorKey] as? Error
            let isFetchError = PBPhotoManager.isFetchImageError(error)
            if isFetchError {
                self?.syncErrorLabel.isHidden = false
                self?.playBtn.setImage(nil, for: .normal)
            }
            if !isDegraded, item != nil {
                self?.fetchVideoDone = true
                self?.configurePlayerLayer(item!)
            }
        })
    }
    
    func configurePlayerLayer(_ item: AVPlayerItem) {
        playBtn.setImage(getImage("pb_playVideo"), for: .normal)
        playBtn.isEnabled = true
        
        player = AVPlayer(playerItem: item)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = bounds
        layer.insertSublayer(playerLayer!, at: 0)
        NotificationCenter.default.addObserver(self, selector: #selector(playFinish), name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
    }
    
    @objc func playBtnClick() {
        let currentTime = player?.currentItem?.currentTime()
        let duration = player?.currentItem?.duration
        if player?.rate == 0 {
            if currentTime?.value == duration?.value {
                player?.currentItem?.seek(to: CMTimeMake(value: 0, timescale: 1), completionHandler: nil)
            }
            imageView.isHidden = true
            player?.play()
            playBtn.setImage(nil, for: .normal)
            singleTapBlock?()
        } else {
            pausePlayer(seekToZero: false)
        }
    }
    
    @objc func playFinish() {
        pausePlayer(seekToZero: true)
    }
    
    @objc func appWillResignActive() {
        if player != nil, player?.rate != 0 {
            pausePlayer(seekToZero: false)
        }
    }
    
    override func previewVCScroll() {
        if player != nil, player?.rate != 0 {
            pausePlayer(seekToZero: false)
        }
    }
    
    override func resetSubViewStatusWhenCellEndDisplay() {
        imageView.isHidden = false
        player?.currentItem?.seek(to: CMTimeMake(value: 0, timescale: 1), completionHandler: nil)
    }
    
    func pausePlayer(seekToZero: Bool) {
        player?.pause()
        if seekToZero {
            player?.seek(to: .zero)
        }
        playBtn.setImage(getImage("pb_playVideo"), for: .normal)
        singleTapBlock?()
    }
    
    func pauseWhileTransition() {
        player?.pause()
        playBtn.setImage(getImage("pb_playVideo"), for: .normal)
    }
    
    override func animateImageFrame(convertTo view: UIView) -> CGRect {
        return convert(imageView.frame, to: view)
    }
    
}


// MARK: net video preview cell
class PBNetVideoPreviewCell: PBPreviewBaseCell {
    
    var player: AVPlayer?
    
    var playerLayer: AVPlayerLayer?
    
    var playBtn: UIButton!
    
    var isPlaying: Bool {
        if player != nil, player?.rate != 0 {
            return true
        }
        return false
    }
    
    var videoUrl: URL! {
        didSet {
            configureCell()
        }
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
        playerLayer?.frame = bounds
        let insets = deviceSafeAreaInsets()
        playBtn.frame = CGRect(x: 0, y: insets.top, width: bounds.width, height: bounds.height - insets.top - insets.bottom)
    }
    
    private func setupUI() {
        playBtn = UIButton(type: .custom)
        playBtn.setImage(getImage("pb_playVideo"), for: .normal)
        playBtn.addTarget(self, action: #selector(playBtnClick), for: .touchUpInside)
        contentView.addSubview(playBtn)
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    func configureCell() {
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        
        player = AVPlayer(playerItem: AVPlayerItem(url: videoUrl))
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = bounds
        layer.insertSublayer(playerLayer!, at: 0)
        NotificationCenter.default.addObserver(self, selector: #selector(playFinish), name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
    }
    
    @objc func playBtnClick() {
        let currentTime = player?.currentItem?.currentTime()
        let duration = player?.currentItem?.duration
        if player?.rate == 0 {
            if currentTime?.value == duration?.value {
                player?.currentItem?.seek(to: CMTimeMake(value: 0, timescale: 1), completionHandler: nil)
            }
            player?.play()
            playBtn.setImage(nil, for: .normal)
            singleTapBlock?()
        } else {
            pausePlayer(seekToZero: false)
        }
    }
    
    @objc func playFinish() {
        pausePlayer(seekToZero: true)
    }
    
    @objc func appWillResignActive() {
        if player != nil, player?.rate != 0 {
            pausePlayer(seekToZero: false)
        }
    }
    
    override func previewVCScroll() {
        if player != nil, player?.rate != 0 {
            pausePlayer(seekToZero: false)
        }
    }
    
    override func resetSubViewStatusWhenCellEndDisplay() {
        player?.currentItem?.seek(to: CMTimeMake(value: 0, timescale: 1), completionHandler: nil)
    }
    
    func pausePlayer(seekToZero: Bool) {
        player?.pause()
        if seekToZero {
            player?.seek(to: .zero)
        }
        playBtn.setImage(getImage("pb_playVideo"), for: .normal)
        singleTapBlock?()
    }
    
}


// MARK: class PBPreviewView
class PBPreviewView: UIView {
    
    static let defaultMaxZoomScale: CGFloat = 3
    
    var scrollView: UIScrollView!
    
    var containerView: UIView!
    
    var imageView: UIImageView!
    
    var image: UIImage? {
        imageView.image
    }
    
    var progressView: PBProgressView!
    
    var singleTapBlock: ( () -> Void )?
    
    var doubleTapBlock: ( () -> Void )?
    
    var imageRequestID: PHImageRequestID = PHInvalidImageRequestID
    
    var gifImageRequestID: PHImageRequestID = PHInvalidImageRequestID
    
    var imageIdentifier: String = ""
    
    var onFetchingGif = false
    
    var fetchGifDone = false
    
    var model: PBPhotoModel! {
        didSet {
            configureView()
        }
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
        scrollView.frame = bounds
        progressView.frame = CGRect(x: bounds.width / 2 - 20, y: bounds.height / 2 - 20, width: 40, height: 40)
        scrollView.zoomScale = 1
        resetSubViewSize()
    }
    
    func setupUI() {
        scrollView = UIScrollView()
        scrollView.maximumZoomScale = PBPreviewView.defaultMaxZoomScale
        scrollView.minimumZoomScale = 1
        scrollView.isMultipleTouchEnabled = true
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delaysContentTouches = false
        addSubview(scrollView)
        
        containerView = UIView()
        scrollView.addSubview(containerView)
        
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        containerView.addSubview(imageView)
        
        progressView = PBProgressView()
        addSubview(progressView)
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapAction(_:)))
        addGestureRecognizer(singleTap)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapAction(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        
        singleTap.require(toFail: doubleTap)
    }
    
    @objc func singleTapAction(_ tap: UITapGestureRecognizer) {
        singleTapBlock?()
    }
    
    @objc func doubleTapAction(_ tap: UITapGestureRecognizer) {
        let scale: CGFloat = scrollView.zoomScale != scrollView.maximumZoomScale ? scrollView.maximumZoomScale : 1
        let tapPoint = tap.location(in: self)
        var rect = CGRect.zero
        rect.size.width = scrollView.frame.width / scale
        rect.size.height = scrollView.frame.height / scale
        rect.origin.x = tapPoint.x - (rect.size.width / 2)
        rect.origin.y = tapPoint.y - (rect.size.height / 2)
        scrollView.zoom(to: rect, animated: true)
    }
    
    func configureView() {
        if imageRequestID > PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(imageRequestID)
        }
        if gifImageRequestID > PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(gifImageRequestID)
        }
        
        scrollView.zoomScale = 1
        imageIdentifier = model.ident
        
        if PhotoConfiguration.default().allowSelectGif, model.type == .gif {
            loadGifFirstFrame()
        } else {
            loadPhoto()
        }
    }
    
    func requestPhotoSize(gif: Bool) -> CGSize {
        // gif 情况下优先加载一个小的缩略图
        var size = model.previewSize
        if gif {
            size.width /= 2
            size.height /= 2
        }
        return size
    }
    
    func loadPhoto() {
        if let editImage = model.editImage {
            imageView.image = editImage
            resetSubViewSize()
        } else {
            imageRequestID = PBPhotoManager.fetchImage(for: model.asset, size: requestPhotoSize(gif: false), progress: { [weak self] (progress, _, _, _) in
                self?.progressView.progress = CGFloat(progress)
                if progress >= 1 {
                    self?.progressView.isHidden = true
                } else {
                    self?.progressView.isHidden = false
                }
            }, completion: { [weak self] (image, isDegraded) in
                guard self?.imageIdentifier == self?.model.ident else {
                    return
                }
                self?.imageView.image = image
                self?.resetSubViewSize()
                if !isDegraded {
                    self?.progressView.isHidden = true
                    self?.imageRequestID = PHInvalidImageRequestID
                }
            })
        }
    }
    
    func loadGifFirstFrame() {
        onFetchingGif = false
        
        imageRequestID = PBPhotoManager.fetchImage(for: model.asset, size: requestPhotoSize(gif: true), completion: { [weak self] (image, isDegraded) in
            guard self?.imageIdentifier == self?.model.ident else {
                return
            }
            self?.imageView.image = image
            self?.resetSubViewSize()
        })
    }
    
    func loadGifData() {
        guard !onFetchingGif else {
            if fetchGifDone {
                resumeGif()
            }
            return
        }
        onFetchingGif = true
        fetchGifDone = false
        imageView.layer.speed = 1
        imageView.layer.timeOffset = 0
        imageView.layer.beginTime = 0
        gifImageRequestID = PBPhotoManager.fetchOriginalImageData(for: model.asset, progress: { [weak self] (progress, _, _, _) in
            self?.progressView.progress = CGFloat(progress)
            if progress >= 1 {
                self?.progressView.isHidden = true
            } else {
                self?.progressView.isHidden = false
            }
        }, completion: { [weak self] (data, _, isDegraded) in
            guard self?.imageIdentifier == self?.model.ident else {
                return
            }
            if !isDegraded {
                self?.fetchGifDone = true
                self?.imageView.image = UIImage.animateGifImage(data: data)
                self?.resetSubViewSize()
            }
        })
    }
    
    func resetSubViewSize() {
        let size: CGSize
        if let _ = model {
            if let ei = model.editImage {
                size = ei.size
            } else {
                size = CGSize(width: model.asset.pixelWidth, height: model.asset.pixelHeight)
            }
        } else {
            size = imageView.image?.size ?? bounds.size
        }
        
        var frame: CGRect = .zero
        
        let viewW = bounds.width
        let viewH = bounds.height
        
        var width = viewW
        
        if isLandscape() {
            let height = viewH
            frame.size.height = height
            
            let imageWHRatio = size.width / size.height
            let viewWHRatio = viewW / viewH
            
            if imageWHRatio > viewWHRatio {
                frame.size.width = floor(height * imageWHRatio)
                if frame.size.width > viewW {
                    // 宽图
                    frame.size.width = viewW
                    frame.size.height = viewW / imageWHRatio
                }
            } else {
                width = floor(height * imageWHRatio)
                if width < 1 || width.isNaN {
                    width = viewW
                }
                frame.size.width = width
            }
        } else {
            frame.size.width = width
            
            let imageHWRatio = size.height / size.width
            let viewHWRatio = viewH / viewW
            
            if imageHWRatio > viewHWRatio {
                // 长图
                frame.size.width = min(size.width, viewW)
                frame.size.height = floor(frame.size.width * imageHWRatio)
            } else {
                var height = floor(frame.size.width * imageHWRatio)
                if height < 1 || height.isNaN {
                    height = viewH
                }
                frame.size.height = height
            }
        }
        
        // 优化 scroll view zoom scale
        if frame.width < frame.height {
            scrollView.maximumZoomScale = max(PBPreviewView.defaultMaxZoomScale, viewW / frame.width)
        } else {
            scrollView.maximumZoomScale = max(PBPreviewView.defaultMaxZoomScale, viewH / frame.height)
        }
        
        containerView.frame = frame
        
        var contenSize: CGSize = .zero
        if isLandscape() {
            contenSize = CGSize(width: width, height: max(viewH, frame.height))
            if frame.height < viewH {
                containerView.center = CGPoint(x: viewW / 2, y: viewH / 2)
            } else {
                containerView.frame = CGRect(origin: CGPoint(x: (viewW-frame.width)/2, y: 0), size: frame.size)
            }
        } else {
            contenSize = frame.size
            if frame.width < viewW || frame.height < viewH {
                containerView.center = CGPoint(x: viewW / 2, y: viewH / 2)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.scrollView.contentSize = contenSize
            self.imageView.frame = self.containerView.bounds
            self.scrollView.contentOffset = .zero
        }
    }
    
    func resumeGif() {
        guard let m = model else { return }
        guard PhotoConfiguration.default().allowSelectGif && m.type == .gif else { return }
        guard imageView.layer.speed != 1 else { return }
        
        let pauseTime = imageView.layer.timeOffset
        imageView.layer.speed = 1
        imageView.layer.timeOffset = 0
        imageView.layer.beginTime = 0
        let timeSincePause = imageView.layer.convertTime(CACurrentMediaTime(), from: nil) - pauseTime
        imageView.layer.beginTime = timeSincePause
    }
    
    func pauseGif() {
        guard let m = model else { return }
        guard PhotoConfiguration.default().allowSelectGif && m.type == .gif else { return }
        guard imageView.layer.speed != 0 else { return }
        
        let pauseTime = imageView.layer.convertTime(CACurrentMediaTime(), from: nil)
        imageView.layer.speed = 0
        imageView.layer.timeOffset = pauseTime
    }
    
}


extension PBPreviewView: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return containerView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let offsetX = (scrollView.frame.width > scrollView.contentSize.width) ? (scrollView.frame.width - scrollView.contentSize.width) * 0.5 : 0
        let offsetY = (scrollView.frame.height > scrollView.contentSize.height) ? (scrollView.frame.height - scrollView.contentSize.height) * 0.5 : 0
        containerView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX, y: scrollView.contentSize.height * 0.5 + offsetY)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        resumeGif()
    }
    
}
