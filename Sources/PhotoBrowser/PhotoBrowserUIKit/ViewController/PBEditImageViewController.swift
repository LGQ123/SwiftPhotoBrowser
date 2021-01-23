//
//  EditImageViewController.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2020/12/30.
//

import UIKit


public class PBEditImageModel: NSObject {
    
    public let drawPaths: [PBDrawPath]
    
    public let mosaicPaths: [PBMosaicPath]
    
    public let editRect: CGRect?
    
    public let angle: CGFloat
    
    public let selectRatio: PBImageClipRatio?
    
    public let selectFilter: PBFilter?
    
    public let textStickers: [(state: PBTextStickerState, index: Int)]?
    
    public let imageStickers: [(state: PBImageStickerState, index: Int)]?
    
    init(drawPaths: [PBDrawPath], mosaicPaths: [PBMosaicPath], editRect: CGRect?, angle: CGFloat, selectRatio: PBImageClipRatio?, selectFilter: PBFilter, textStickers: [(state: PBTextStickerState, index: Int)]?, imageStickers: [(state: PBImageStickerState, index: Int)]?) {
        self.drawPaths = drawPaths
        self.mosaicPaths = mosaicPaths
        self.editRect = editRect
        self.angle = angle
        self.selectRatio = selectRatio
        self.selectFilter = selectFilter
        self.textStickers = textStickers
        self.imageStickers = imageStickers
        super.init()
    }
}

public class PBEditImageViewController: UIViewController {
    
    static let filterColViewH: CGFloat = 80
    
    static let maxDrawLineImageWidth: CGFloat = 600
    
    static let ashbinNormalBgColor = RGB(40, 40, 40).withAlphaComponent(0.8)
    
    var animate = false
    
    var originalImage: UIImage
    
    // 第一次进入界面时，布局后frame，裁剪dimiss动画使用
    var originalFrame: CGRect = .zero
    
    // 图片可编辑rect
    var editRect: CGRect
    
    let tools: [EditImageTool]
    
    var selectRatio: PBImageClipRatio?
    
    var editImage: UIImage
    
    var cancelBtn: UIButton!
    
    var scrollView: UIScrollView!
    
    var containerView: UIView!
    
    // Show image.
    var imageView: UIImageView!
    
    // Show draw lines.
    var drawingImageView: UIImageView!
    
    // Show text and image stickers.
    var stickersContainer: UIView!
    
    // 处理好的马赛克图片
    var mosaicImage: UIImage?
    
    // 显示马赛克图片的layer
    var mosaicImageLayer: CALayer?
    
    // 显示马赛克图片的layer的mask
    var mosaicImageLayerMaskLayer: CAShapeLayer?
    
    // 上方渐变阴影层
    var topShadowView: UIView!
    
    var topShadowLayer: CAGradientLayer!
     
    // 下方渐变阴影层
    var bottomShadowView: UIView!
    
    var bottomShadowLayer: CAGradientLayer!
    
    var doneBtn: UIButton!
    
    var revokeBtn: UIButton!
    
    var selectedTool: EditImageTool?
    
    var editToolCollectionView: UICollectionView!
    
    var drawColorCollectionView: UICollectionView!
    
    var filterCollectionView: UICollectionView!
    
    var ashbinView: UIView!
    
    var ashbinImgView: UIImageView!
    
    let drawColors: [UIColor]
    
    var currentDrawColor = PhotoConfiguration.default().editImageDefaultDrawColor
    
    var drawPaths: [PBDrawPath]
    
    var drawLineWidth: CGFloat = 5
    
    var mosaicPaths: [PBMosaicPath]
    
    var mosaicLineWidth: CGFloat = 25
    
    // collectionview 中的添加滤镜的小图
    var thumbnailFilterImages: [UIImage] = []
    
    // 选择滤镜后对原图添加滤镜后的图片
    var filterImages: [String: UIImage] = [:]
    
    var currentFilter: PBFilter
    
    var stickers: [UIView] = []
    
    var isScrolling = false
    
    var shouldLayout = true
    
    var imageStickerContainerIsHidden = true
    
    var angle: CGFloat
    
    var panGes: UIPanGestureRecognizer!
    
    var imageSize: CGSize {
        if angle == -90 || angle == -270 {
            return CGSize(width: originalImage.size.height, height: originalImage.size.width)
        }
        return originalImage.size
    }
    
    @objc public var editFinishBlock: ( (UIImage, PBEditImageModel?) -> Void )?
    
    public override var prefersStatusBarHidden: Bool {
        return true
    }
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    @objc public class func showEditImageVC(parentVC: UIViewController?, animate: Bool = false, image: UIImage, editModel: PBEditImageModel? = nil, completion: ( (UIImage, PBEditImageModel?) -> Void )? ) {
        let tools = PhotoConfiguration.default().editImageTools
        if PhotoConfiguration.default().showClipDirectlyIfOnlyHasClipTool, tools.count == 1, tools.contains(.clip) {
            let vc = PBClipImageViewController(image: image, editRect: editModel?.editRect, angle: editModel?.angle ?? 0, selectRatio: editModel?.selectRatio)
            vc.clipDoneBlock = { (angle, editRect, ratio) in
                let m = PBEditImageModel(drawPaths: [], mosaicPaths: [], editRect: editRect, angle: angle, selectRatio: ratio, selectFilter: .normal, textStickers: nil, imageStickers: nil)
                completion?(image.clipImage(angle, editRect) ?? image, m)
            }
            vc.animate = animate
            vc.modalPresentationStyle = .fullScreen
            parentVC?.present(vc, animated: animate, completion: nil)
        } else {
            let vc = PBEditImageViewController(image: image, editModel: editModel)
            vc.editFinishBlock = {  (ei, editImageModel) in
                completion?(ei, editImageModel)
            }
            vc.animate = animate
            vc.modalPresentationStyle = .fullScreen
            parentVC?.present(vc, animated: animate, completion: nil)
        }
    }
    
    @objc public init(image: UIImage, editModel: PBEditImageModel? = nil) {
        originalImage = image
        editImage = image
        editRect = editModel?.editRect ?? CGRect(origin: .zero, size: image.size)
        drawColors = PhotoConfiguration.default().editImageDrawColors
        currentFilter = editModel?.selectFilter ?? .normal
        drawPaths = editModel?.drawPaths ?? []
        mosaicPaths = editModel?.mosaicPaths ?? []
        angle = editModel?.angle ?? 0
        selectRatio = editModel?.selectRatio
        
        var ts = PhotoConfiguration.default().editImageTools
        if ts.contains(.imageSticker), PhotoConfiguration.default().imageStickerContainerView == nil {
            ts.removeAll { $0 == .imageSticker }
        }
        tools = ts
        
        super.init(nibName: nil, bundle: nil)
        
        if !drawColors.contains(currentDrawColor) {
            currentDrawColor = drawColors.first!
        }
        
        let teStic = editModel?.textStickers ?? []
        let imStic = editModel?.imageStickers ?? []
        
        var stickers: [UIView?] = Array(repeating: nil, count: teStic.count + imStic.count)
        teStic.forEach { (cache) in
            let v = PBTextStickerView(from: cache.state)
            stickers[cache.index] = v
        }
        imStic.forEach { (cache) in
            let v = PBImageStickerView(from: cache.state)
            stickers[cache.index] = v
        }
        
        self.stickers = stickers.compactMap { $0 }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        rotationImageView()
        if tools.contains(.filter) {
            generateFilterImages()
        }
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
        
        scrollView.frame = self.view.bounds
        resetContainerViewFrame()
        
        topShadowView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 150)
        topShadowLayer.frame = self.topShadowView.bounds
        cancelBtn.frame = CGRect(x: 30, y: insets.top+10, width: 28, height: 28)
        
        bottomShadowView.frame = CGRect(x: 0, y: self.view.frame.height-140-insets.bottom, width: self.view.frame.width, height: 140+insets.bottom)
        bottomShadowLayer.frame = self.bottomShadowView.bounds
        
        drawColorCollectionView.frame = CGRect(x: 20, y: 20, width: self.view.frame.width - 80, height: 50)
        revokeBtn.frame = CGRect(x: self.view.frame.width - 15 - 35, y: 30, width: 35, height: 30)
        
        filterCollectionView.frame = CGRect(x: 20, y: 0, width: self.view.frame.width-40, height: PBEditImageViewController.filterColViewH)
        
        let toolY: CGFloat = 85
        
        let doneBtnH = PBLayout.bottomToolBtnH
        let doneBtnW:CGFloat = 40.0
        doneBtn.frame = CGRect(x: view.frame.width-20-doneBtnW, y: toolY-2, width: doneBtnW, height: doneBtnH)
        
        editToolCollectionView.frame = CGRect(x: 20, y: toolY, width: view.bounds.width - 20 - 20 - doneBtnW - 20, height: 30)
        
        if !drawPaths.isEmpty {
            drawLine()
        }
        if !mosaicPaths.isEmpty {
            generateNewMosaicImage()
        }
        
        if let index = drawColors.firstIndex(where: { $0 == currentDrawColor}) {
            drawColorCollectionView.scrollToItem(at: IndexPath(row: index, section: 0), at: .centeredHorizontally, animated: false)
        }
    }
    
    func generateFilterImages() {
        let size: CGSize
        let ratio = (originalImage.size.width / originalImage.size.height)
        let fixLength: CGFloat = 200
        if ratio >= 1 {
            size = CGSize(width: fixLength * ratio, height: fixLength)
        } else {
            size = CGSize(width: fixLength, height: fixLength / ratio)
        }
        let thumbnailImage = originalImage.resize(size) ?? originalImage
        
        DispatchQueue.global().async {
            self.thumbnailFilterImages = PhotoConfiguration.default().filters.map { $0.applier?(thumbnailImage) ?? thumbnailImage }
            
            DispatchQueue.main.async {
                self.filterCollectionView.reloadData()
                self.filterCollectionView.performBatchUpdates {
                    
                } completion: { (_) in
                    if let index = PhotoConfiguration.default().filters.firstIndex(where: { $0 == self.currentFilter }) {
                        self.filterCollectionView.scrollToItem(at: IndexPath(row: index, section: 0), at: .centeredHorizontally, animated: false)
                    }
                }

            }
        }
    }
    
    func resetContainerViewFrame() {
        scrollView.setZoomScale(1, animated: true)
        imageView.image = editImage
        
        let editSize = editRect.size
        let scrollViewSize = scrollView.frame.size
        let ratio = min(scrollViewSize.width / editSize.width, scrollViewSize.height / editSize.height)
        let w = ratio * editSize.width * scrollView.zoomScale
        let h = ratio * editSize.height * scrollView.zoomScale
        containerView.frame = CGRect(x: max(0, (scrollViewSize.width-w)/2), y: max(0, (scrollViewSize.height-h)/2), width: w, height: h)
        
        let scaleImageOrigin = CGPoint(x: -editRect.origin.x*ratio, y: -editRect.origin.y*ratio)
        let scaleImageSize = CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
        imageView.frame = CGRect(origin: scaleImageOrigin, size: scaleImageSize)
        mosaicImageLayer?.frame = imageView.bounds
        mosaicImageLayerMaskLayer?.frame = imageView.bounds
        drawingImageView.frame = imageView.frame
        stickersContainer.frame = imageView.frame
        
        // 针对于长图的优化
        if (editRect.height / editRect.width) > (view.frame.height / view.frame.width * 1.1) {
            let widthScale = view.frame.width / w
            scrollView.maximumZoomScale = widthScale
            scrollView.zoomScale = widthScale
            scrollView.contentOffset = .zero
        } else if editRect.width / editRect.height > 1 {
            scrollView.maximumZoomScale = max(3, view.frame.height / h)
        }
        
        originalFrame = self.view.convert(containerView.frame, from: scrollView)
        isScrolling = false
    }
    
    func setupUI() {
        view.backgroundColor = .black
        
        scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 3
        scrollView.delegate = self
        view.addSubview(self.scrollView)
        
        containerView = UIView()
        containerView.clipsToBounds = true
        scrollView.addSubview(self.containerView)
        
        imageView = UIImageView(image: self.originalImage)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .black
        containerView.addSubview(imageView)
        
        drawingImageView = UIImageView()
        drawingImageView.contentMode = .scaleAspectFit
        drawingImageView.isUserInteractionEnabled = true
        containerView.addSubview(drawingImageView)
        
        stickersContainer = UIView()
        containerView.addSubview(stickersContainer)
        
        let color1 = UIColor.black.withAlphaComponent(0.35).cgColor
        let color2 = UIColor.black.withAlphaComponent(0).cgColor
        topShadowView = UIView()
        view.addSubview(topShadowView)
        
        topShadowLayer = CAGradientLayer()
        topShadowLayer.colors = [color1, color2]
        topShadowLayer.locations = [0, 1]
        topShadowView.layer.addSublayer(topShadowLayer)
        
        cancelBtn = UIButton(type: .custom)
        cancelBtn.setImage(getImage("pb_retake"), for: .normal)
        cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        cancelBtn.adjustsImageWhenHighlighted = false
        cancelBtn.pb_enlargeValidTouchArea(inset: 30)
        topShadowView.addSubview(cancelBtn)
        
        bottomShadowView = UIView()
        view.addSubview(bottomShadowView)
        
        bottomShadowLayer = CAGradientLayer()
        bottomShadowLayer.colors = [color2, color1]
        bottomShadowLayer.locations = [0, 1]
        bottomShadowView.layer.addSublayer(bottomShadowLayer)
        
        let editToolLayout = UICollectionViewFlowLayout()
        editToolLayout.itemSize = CGSize(width: 30, height: 30)
        editToolLayout.minimumLineSpacing = 20
        editToolLayout.minimumInteritemSpacing = 20
        editToolLayout.scrollDirection = .horizontal
        editToolCollectionView = UICollectionView(frame: .zero, collectionViewLayout: editToolLayout)
        editToolCollectionView.backgroundColor = .clear
        editToolCollectionView.delegate = self
        editToolCollectionView.dataSource = self
        editToolCollectionView.showsHorizontalScrollIndicator = false
        bottomShadowView.addSubview(editToolCollectionView)
        
        PBEditToolCell.pb_register(editToolCollectionView)
        
        doneBtn = UIButton(type: .custom)
        doneBtn.titleLabel?.font = PBLayout.bottomToolTitleFont
        doneBtn.backgroundColor = .bottomToolViewBtnNormalBgColor
        doneBtn.setTitle("完成", for: .normal)
        doneBtn.addTarget(self, action: #selector(doneBtnClick), for: .touchUpInside)
        doneBtn.layer.masksToBounds = true
        doneBtn.layer.cornerRadius = PBLayout.bottomToolBtnCornerRadius
        bottomShadowView.addSubview(doneBtn)
        
        let drawColorLayout = UICollectionViewFlowLayout()
        drawColorLayout.itemSize = CGSize(width: 30, height: 30)
        drawColorLayout.minimumLineSpacing = 15
        drawColorLayout.minimumInteritemSpacing = 15
        drawColorLayout.scrollDirection = .horizontal
        drawColorLayout.sectionInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        drawColorCollectionView = UICollectionView(frame: .zero, collectionViewLayout: drawColorLayout)
        drawColorCollectionView.backgroundColor = .clear
        drawColorCollectionView.delegate = self
        drawColorCollectionView.dataSource = self
        drawColorCollectionView.isHidden = true
        drawColorCollectionView.showsHorizontalScrollIndicator = false
        bottomShadowView.addSubview(drawColorCollectionView)
        
        PBDrawColorCell.pb_register(drawColorCollectionView)
        
        let filterLayout = UICollectionViewFlowLayout()
        filterLayout.itemSize = CGSize(width: PBEditImageViewController.filterColViewH-20, height: PBEditImageViewController.filterColViewH)
        filterLayout.minimumLineSpacing = 15
        filterLayout.minimumInteritemSpacing = 15
        filterLayout.scrollDirection = .horizontal
        filterCollectionView = UICollectionView(frame: .zero, collectionViewLayout: filterLayout)
        filterCollectionView.backgroundColor = .clear
        filterCollectionView.delegate = self
        filterCollectionView.dataSource = self
        filterCollectionView.isHidden = true
        filterCollectionView.showsHorizontalScrollIndicator = false
        bottomShadowView.addSubview(filterCollectionView)
        
        PBFilterImageCell.pb_register(filterCollectionView)
        
        revokeBtn = UIButton(type: .custom)
        revokeBtn.setImage(getImage("pb_revoke_disable"), for: .disabled)
        revokeBtn.setImage(getImage("pb_revoke"), for: .normal)
        revokeBtn.adjustsImageWhenHighlighted = false
        revokeBtn.isEnabled = false
        revokeBtn.isHidden = true
        revokeBtn.addTarget(self, action: #selector(revokeBtnClick), for: .touchUpInside)
        bottomShadowView.addSubview(revokeBtn)
        
        let ashbinSize = CGSize(width: 160, height: 80)
        ashbinView = UIView(frame: CGRect(x: (view.frame.width-ashbinSize.width)/2, y: view.frame.height-ashbinSize.height-40, width: ashbinSize.width, height: ashbinSize.height))
        ashbinView.backgroundColor = PBEditImageViewController.ashbinNormalBgColor
        ashbinView.layer.cornerRadius = 15
        ashbinView.layer.masksToBounds = true
        ashbinView.isHidden = true
        view.addSubview(ashbinView)
        
        ashbinImgView = UIImageView(image: getImage("pb_ashbin"), highlightedImage: getImage("pb_ashbin_open"))
        ashbinImgView.frame = CGRect(x: (ashbinSize.width-25)/2, y: 15, width: 25, height: 25)
        ashbinView.addSubview(ashbinImgView)
        
        let asbinTipLabel = UILabel(frame: CGRect(x: 0, y: ashbinSize.height-34, width: ashbinSize.width, height: 34))
        asbinTipLabel.font = UIFont.systemFont(ofSize: 12)
        asbinTipLabel.textAlignment = .center
        asbinTipLabel.textColor = .white
        asbinTipLabel.text = "拖到此处删除"
        asbinTipLabel.numberOfLines = 2
        asbinTipLabel.lineBreakMode = .byCharWrapping
        ashbinView.addSubview(asbinTipLabel)
        
        if tools.contains(.mosaic) {
            // 之前选择过滤镜
            if let applier = currentFilter.applier {
                let image = applier(originalImage)
                editImage = image
                filterImages[currentFilter.name] = image
                
                mosaicImage = editImage.mosaicImage()
            } else {
                mosaicImage = originalImage.mosaicImage()
            }
            
            mosaicImageLayer = CALayer()
            mosaicImageLayer?.contents = mosaicImage?.cgImage
            imageView.layer.addSublayer(mosaicImageLayer!)
            
            mosaicImageLayerMaskLayer = CAShapeLayer()
            mosaicImageLayerMaskLayer?.strokeColor = UIColor.blue.cgColor
            mosaicImageLayerMaskLayer?.fillColor = nil
            mosaicImageLayerMaskLayer?.lineCap = .round
            mosaicImageLayerMaskLayer?.lineJoin = .round
            imageView.layer.addSublayer(mosaicImageLayerMaskLayer!)
            
            mosaicImageLayer?.mask = mosaicImageLayerMaskLayer
        }
        
        if tools.contains(.imageSticker) {
            PhotoConfiguration.default().imageStickerContainerView?.hideBlock = { [weak self] in
                self?.setToolView(show: true)
                self?.imageStickerContainerIsHidden = true
            }
            
            PhotoConfiguration.default().imageStickerContainerView?.selectImageBlock = { [weak self] (image) in
                self?.addImageStickerView(image)
            }
        }
        
        let tapGes = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        tapGes.delegate = self
        view.addGestureRecognizer(tapGes)
        
        panGes = UIPanGestureRecognizer(target: self, action: #selector(drawAction(_:)))
        panGes.maximumNumberOfTouches = 1
        panGes.delegate = self
        view.addGestureRecognizer(panGes)
        scrollView.panGestureRecognizer.require(toFail: panGes)
        
        stickers.forEach { (view) in
            stickersContainer.addSubview(view)
            if let tv = view as? PBTextStickerView {
                tv.frame = tv.originFrame
                configTextSticker(tv)
            } else if let iv = view as? PBImageStickerView {
                iv.frame = iv.originFrame
                configImageSticker(iv)
            }
        }
    }
    
    func rotationImageView() {
        let transform = CGAffineTransform(rotationAngle: angle.pb_toPi)
        imageView.transform = transform
        drawingImageView.transform = transform
        stickersContainer.transform = transform
    }
    
    @objc func cancelBtnClick() {
        dismiss(animated: animate, completion: nil)
    }
    
    func drawBtnClick() {
        let isSelected = selectedTool != .draw
        if isSelected {
            selectedTool = .draw
        } else {
            selectedTool = nil
        }
        drawColorCollectionView.isHidden = !isSelected
        revokeBtn.isHidden = !isSelected
        revokeBtn.isEnabled = drawPaths.count > 0
        filterCollectionView.isHidden = true
    }
    
    func clipBtnClick() {
        let currentEditImage = buildImage()
        let vc = PBClipImageViewController(image: currentEditImage, editRect: editRect, angle: angle, selectRatio: selectRatio)
        let rect = scrollView.convert(containerView.frame, to: view)
        vc.presentAnimateFrame = rect
        vc.presentAnimateImage = currentEditImage.clipImage(angle, editRect)
        vc.modalPresentationStyle = .fullScreen
        
        vc.clipDoneBlock = { [weak self] (angle, editFrame, selectRatio) in
            guard let `self` = self else { return }
            let oldAngle = self.angle
            let oldContainerSize = self.stickersContainer.frame.size
            if self.angle != angle {
                self.angle = angle
                self.rotationImageView()
            }
            self.editRect = editFrame
            self.selectRatio = selectRatio
            self.resetContainerViewFrame()
            self.reCalculateStickersFrame(oldContainerSize, oldAngle, angle)
        }
        
        vc.cancelClipBlock = { [weak self] () in
            self?.resetContainerViewFrame()
        }
        
        self.present(vc, animated: false) {
            self.scrollView.alpha = 0
            self.topShadowView.alpha = 0
            self.bottomShadowView.alpha = 0
        }
    }
    
    func imageStickerBtnClick() {
        PhotoConfiguration.default().imageStickerContainerView?.show(in: view)
        setToolView(show: false)
        imageStickerContainerIsHidden = false
    }
    
    func textStickerBtnClick() {
        showInputTextVC { [weak self] (text, textColor, bgColor) in
            self?.addTextStickersView(text, textColor: textColor, bgColor: bgColor)
        }
    }
    
    func mosaicBtnClick() {
        let isSelected = selectedTool != .mosaic
        if isSelected {
            selectedTool = .mosaic
        } else {
            selectedTool = nil
        }
        
        drawColorCollectionView.isHidden = true
        filterCollectionView.isHidden = true
        revokeBtn.isHidden = !isSelected
        revokeBtn.isEnabled = mosaicPaths.count > 0
    }
    
    func filterBtnClick() {
        let isSelected = selectedTool != .filter
        if isSelected {
            selectedTool = .filter
        } else {
            selectedTool = nil
        }
        
        drawColorCollectionView.isHidden = true
        revokeBtn.isHidden = true
        filterCollectionView.isHidden = !isSelected
    }
    
    @objc func doneBtnClick() {
        var textStickers: [(PBTextStickerState, Int)] = []
        var imageStickers: [(PBImageStickerState, Int)] = []
        for (index, view) in stickersContainer.subviews.enumerated() {
            if let ts = view as? PBTextStickerView, let _ = ts.label.text {
                textStickers.append((ts.state, index))
            } else if let ts = view as? PBImageStickerView {
                imageStickers.append((ts.state, index))
            }
        }
        
        var hasEdit = true
        if drawPaths.isEmpty, editRect.size == imageSize, angle == 0, mosaicPaths.isEmpty, imageStickers.isEmpty, textStickers.isEmpty, currentFilter.applier == nil {
            hasEdit = false
        }
        
        var resImage = originalImage
        var editModel: PBEditImageModel? = nil
        if hasEdit {
            resImage = buildImage()
            resImage = resImage.clipImage(angle, editRect) ?? resImage
            editModel = PBEditImageModel(drawPaths: drawPaths, mosaicPaths: mosaicPaths, editRect: editRect, angle: angle, selectRatio: selectRatio, selectFilter: currentFilter, textStickers: textStickers, imageStickers: imageStickers)
        }
        editFinishBlock?(resImage, editModel)
        
        dismiss(animated: animate, completion: nil)
    }
    
    @objc func revokeBtnClick() {
        if self.selectedTool == .draw {
            guard !drawPaths.isEmpty else {
                return
            }
            drawPaths.removeLast()
            revokeBtn.isEnabled = drawPaths.count > 0
            drawLine()
        } else if selectedTool == .mosaic {
            guard !mosaicPaths.isEmpty else {
                return
            }
            mosaicPaths.removeLast()
            revokeBtn.isEnabled = mosaicPaths.count > 0
            generateNewMosaicImage()
        }
    }
    
    @objc func tapAction(_ tap: UITapGestureRecognizer) {
        if bottomShadowView.alpha == 1 {
            setToolView(show: false)
        } else {
            setToolView(show: true)
        }
    }
    
    @objc func drawAction(_ pan: UIPanGestureRecognizer) {
        if selectedTool == .draw {
            let point = pan.location(in: drawingImageView)
            if pan.state == .began {
                setToolView(show: false)
                
                let originalRatio = min(scrollView.frame.width / originalImage.size.width, scrollView.frame.height / originalImage.size.height)
                let ratio = min(scrollView.frame.width / editRect.width, scrollView.frame.height / editRect.height)
                let scale = ratio / originalRatio
                // 缩放到最初的size
                var size = drawingImageView.frame.size
                size.width /= scale
                size.height /= scale
                if angle == -90 || angle == -270 {
                    swap(&size.width, &size.height)
                }
                
                var toImageScale = PBEditImageViewController.maxDrawLineImageWidth / size.width
                if editImage.size.width / editImage.size.height > 1 {
                    toImageScale = PBEditImageViewController.maxDrawLineImageWidth / size.height
                }
                
                let path = PBDrawPath(pathColor: currentDrawColor, pathWidth: drawLineWidth / scrollView.zoomScale, ratio: ratio / originalRatio / toImageScale, startPoint: point)
                drawPaths.append(path)
            } else if pan.state == .changed {
                let path = drawPaths.last
                path?.addLine(to: point)
                drawLine()
            } else if pan.state == .cancelled || pan.state == .ended {
                setToolView(show: true)
                revokeBtn.isEnabled = drawPaths.count > 0
            }
        } else if selectedTool == .mosaic {
            let point = pan.location(in: imageView)
            if pan.state == .began {
                setToolView(show: false)
                
                var actualSize = editRect.size
                if angle == -90 || angle == -270 {
                    swap(&actualSize.width, &actualSize.height)
                }
                let ratio = min(scrollView.frame.width / editRect.width, scrollView.frame.height / editRect.height)
                
                let pathW = mosaicLineWidth / scrollView.zoomScale
                let path = PBMosaicPath(pathWidth: pathW, ratio: ratio, startPoint: point)
                
                mosaicImageLayerMaskLayer?.lineWidth = pathW
                mosaicImageLayerMaskLayer?.path = path.path.cgPath
                mosaicPaths.append(path)
            } else if pan.state == .changed {
                let path = mosaicPaths.last
                path?.addLine(to: point)
                mosaicImageLayerMaskLayer?.path = path?.path.cgPath
            } else if pan.state == .cancelled || pan.state == .ended {
                setToolView(show: true)
                revokeBtn.isEnabled = mosaicPaths.count > 0
                generateNewMosaicImage()
            }
        }
    }
    
    func setToolView(show: Bool) {
        topShadowView.layer.removeAllAnimations()
        bottomShadowView.layer.removeAllAnimations()
        if show {
            UIView.animate(withDuration: 0.25) {
                self.topShadowView.alpha = 1
                self.bottomShadowView.alpha = 1
            }
        } else {
            UIView.animate(withDuration: 0.25) {
                self.topShadowView.alpha = 0
                self.bottomShadowView.alpha = 0
            }
        }
    }
    
    func showInputTextVC(_ text: String? = nil, textColor: UIColor? = nil, bgColor: UIColor? = nil, completion: @escaping ( (String, UIColor, UIColor) -> Void )) {
        // Calculate image displayed frame on the screen.
        var r = scrollView.convert(view.frame, to: containerView)
        r.origin.x += scrollView.contentOffset.x / scrollView.zoomScale
        r.origin.y += scrollView.contentOffset.y / scrollView.zoomScale
        let scale = imageSize.width / imageView.frame.width
        r.origin.x *= scale
        r.origin.y *= scale
        r.size.width *= scale
        r.size.height *= scale
        let bgImage = buildImage().clipImage(angle, editRect)?.clipImage(0, r)
        let vc = PBInputTextViewController(image: bgImage, text: text, textColor: textColor, bgColor: bgColor)
        
        vc.endInput = { (text, textColor, bgColor) in
            completion(text, textColor, bgColor)
        }
        
        vc.modalPresentationStyle = .fullScreen
        showDetailViewController(vc, sender: nil)
    }
    
    func getStickerOriginFrame(_ size: CGSize) -> CGRect {
        let scale = scrollView.zoomScale
        // Calculate the display rect of container view.
        let x = (scrollView.contentOffset.x - containerView.frame.minX) / scale
        let y = (scrollView.contentOffset.y - containerView.frame.minY) / scale
        let w = view.frame.width / scale
        let h = view.frame.height / scale
        // Convert to text stickers container view.
        let r = containerView.convert(CGRect(x: x, y: y, width: w, height: h), to: stickersContainer)
        let originFrame = CGRect(x: r.minX + (r.width - size.width) / 2, y: r.minY + (r.height - size.height) / 2, width: size.width, height: size.height)
        return originFrame
    }
    
    /// Add image sticker
    func addImageStickerView(_ image: UIImage) {
        let scale = scrollView.zoomScale
        let size = PBImageStickerView.calculateSize(image: image, width: view.frame.width)
        let originFrame = getStickerOriginFrame(size)
        
        let imageSticker = PBImageStickerView(image: image, originScale: 1 / scale, originAngle: -angle, originFrame: originFrame)
        stickersContainer.addSubview(imageSticker)
        imageSticker.frame = originFrame
        view.layoutIfNeeded()
        
        configImageSticker(imageSticker)
    }
    
    /// Add text sticker
    func addTextStickersView(_ text: String, textColor: UIColor, bgColor: UIColor) {
        guard !text.isEmpty else { return }
        let scale = scrollView.zoomScale
        let size = PBTextStickerView.calculateSize(text: text, width: view.frame.width)
        let originFrame = getStickerOriginFrame(size)
        
        let textSticker = PBTextStickerView(text: text, textColor: textColor, bgColor: bgColor, originScale: 1 / scale, originAngle: -angle, originFrame: originFrame)
        stickersContainer.addSubview(textSticker)
        textSticker.frame = originFrame
        
        configTextSticker(textSticker)
    }
    
    func configTextSticker(_ textSticker: PBTextStickerView) {
        textSticker.delegate = self
        scrollView.pinchGestureRecognizer?.require(toFail: textSticker.pinchGes)
        scrollView.panGestureRecognizer.require(toFail: textSticker.panGes)
        panGes.require(toFail: textSticker.panGes)
    }
    
    func configImageSticker(_ imageSticker: PBImageStickerView) {
        imageSticker.delegate = self
        scrollView.pinchGestureRecognizer?.require(toFail: imageSticker.pinchGes)
        scrollView.panGestureRecognizer.require(toFail: imageSticker.panGes)
        panGes.require(toFail: imageSticker.panGes)
    }
    
    func reCalculateStickersFrame(_ oldSize: CGSize, _ oldAngle: CGFloat, _ newAngle: CGFloat) {
        let currSize = stickersContainer.frame.size
        let scale: CGFloat
        if Int(newAngle - oldAngle) % 180 == 0{
            scale = currSize.width / oldSize.width
        } else {
            scale = currSize.height / oldSize.width
        }
        
        stickersContainer.subviews.forEach { (view) in
            (view as? PBStickerViewAdditional)?.addScale(scale)
        }
    }
    
    func drawLine() {
        let originalRatio = min(scrollView.frame.width / originalImage.size.width, scrollView.frame.height / originalImage.size.height)
        let ratio = min(scrollView.frame.width / editRect.width, scrollView.frame.height / editRect.height)
        let scale = ratio / originalRatio
        // 缩放到最初的size
        var size = drawingImageView.frame.size
        size.width /= scale
        size.height /= scale
        if angle == -90 || angle == -270 {
            swap(&size.width, &size.height)
        }
        var toImageScale = PBEditImageViewController.maxDrawLineImageWidth / size.width
        if editImage.size.width / editImage.size.height > 1 {
            toImageScale = PBEditImageViewController.maxDrawLineImageWidth / size.height
        }
        size.width *= toImageScale
        size.height *= toImageScale
        
        UIGraphicsBeginImageContextWithOptions(size, false, editImage.scale)
        let context = UIGraphicsGetCurrentContext()
        // 去掉锯齿
        context?.setAllowsAntialiasing(true)
        context?.setShouldAntialias(true)
        for path in drawPaths {
            path.drawPath()
        }
        drawingImageView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
    
    func generateNewMosaicImage() {
        UIGraphicsBeginImageContextWithOptions(originalImage.size, false, originalImage.scale)
        if tools.contains(.filter), let image = filterImages[currentFilter.name] {
            image.draw(at: .zero)
        } else {
            originalImage.draw(at: .zero)
        }
        let context = UIGraphicsGetCurrentContext()
        
        mosaicPaths.forEach { (path) in
            context?.move(to: path.startPoint)
            path.linePoints.forEach { (point) in
                context?.addLine(to: point)
            }
            context?.setLineWidth(path.path.lineWidth / path.ratio)
            context?.setLineCap(.round)
            context?.setLineJoin(.round)
            context?.setBlendMode(.clear)
            context?.strokePath()
        }
        
        var midImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let midCgImage = midImage?.cgImage else {
            return
        }
        
        midImage = UIImage(cgImage: midCgImage, scale: editImage.scale, orientation: .up)
        
        UIGraphicsBeginImageContextWithOptions(originalImage.size, false, originalImage.scale)
        mosaicImage?.draw(at: .zero)
        midImage?.draw(at: .zero)
        
        let temp = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cgi = temp?.cgImage else {
            return
        }
        let image = UIImage(cgImage: cgi, scale: editImage.scale, orientation: .up)
        
        editImage = image
        imageView.image = editImage
        
        mosaicImageLayerMaskLayer?.path = nil
    }
    
    func buildImage() -> UIImage {
        let imageSize = originalImage.size
        
        UIGraphicsBeginImageContextWithOptions(editImage.size, false, editImage.scale)
        editImage.draw(at: .zero)
        
        drawingImageView.image?.draw(in: CGRect(origin: .zero, size: imageSize))
        
        if !stickersContainer.subviews.isEmpty, let context = UIGraphicsGetCurrentContext() {
            let scale = imageSize.width / stickersContainer.frame.width
            stickersContainer.subviews.forEach { (view) in
                (view as? PBStickerViewAdditional)?.resetState()
            }
            context.concatenate(CGAffineTransform(scaleX: scale, y: scale))
            stickersContainer.layer.render(in: context)
            context.concatenate(CGAffineTransform(scaleX: 1/scale, y: 1/scale))
        }
        
        let temp = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cgi = temp?.cgImage else {
            return editImage
        }
        return UIImage(cgImage: cgi, scale: editImage.scale, orientation: .up)
    }
    
    func finishClipDismissAnimate() {
        scrollView.alpha = 1
        UIView.animate(withDuration: 0.1) {
            self.topShadowView.alpha = 1
            self.bottomShadowView.alpha = 1
        }
    }
    
}

extension PBEditImageViewController: UIGestureRecognizerDelegate {
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard imageStickerContainerIsHidden else {
            return false
        }
        if gestureRecognizer is UITapGestureRecognizer {
            if bottomShadowView.alpha == 1 {
                let p = gestureRecognizer.location(in: view)
                return !bottomShadowView.frame.contains(p)
            } else {
                return true
            }
        } else if gestureRecognizer is UIPanGestureRecognizer {
            guard let st = selectedTool else {
                return false
            }
            return (st == .draw || st == .mosaic) && !isScrolling
        }
        
        return true
    }
    
}

// MARK: scroll view delegate
extension PBEditImageViewController: UIScrollViewDelegate {
    
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return containerView
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let offsetX = (scrollView.frame.width > scrollView.contentSize.width) ? (scrollView.frame.width - scrollView.contentSize.width) * 0.5 : 0
        let offsetY = (scrollView.frame.height > scrollView.contentSize.height) ? (scrollView.frame.height - scrollView.contentSize.height) * 0.5 : 0
        containerView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX, y: scrollView.contentSize.height * 0.5 + offsetY)
    }
    
    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        isScrolling = false
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == self.scrollView else {
            return
        }
        isScrolling = true
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView == self.scrollView else {
            return
        }
        isScrolling = decelerate
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == self.scrollView else {
            return
        }
        isScrolling = false
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView == self.scrollView else {
            return
        }
        isScrolling = false
    }
    
}

extension PBEditImageViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == editToolCollectionView {
            return tools.count
        } else if collectionView == drawColorCollectionView {
            return drawColors.count
        } else {
            return thumbnailFilterImages.count
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == editToolCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PBEditToolCell.pb_identifier(), for: indexPath) as! PBEditToolCell
            
            let toolType = tools[indexPath.row]
            cell.icon.isHighlighted = false
            cell.toolType = toolType
            cell.icon.isHighlighted = toolType == selectedTool
            
            return cell
        } else if collectionView == drawColorCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PBDrawColorCell.pb_identifier(), for: indexPath) as! PBDrawColorCell
            
            let c = drawColors[indexPath.row]
            cell.color = c
            if c == currentDrawColor {
                cell.bgWhiteView.layer.transform = CATransform3DMakeScale(1.2, 1.2, 1)
            } else {
                cell.bgWhiteView.layer.transform = CATransform3DIdentity
            }
            
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PBFilterImageCell.pb_identifier(), for: indexPath) as! PBFilterImageCell
            
            let image = thumbnailFilterImages[indexPath.row]
            let filter = PhotoConfiguration.default().filters[indexPath.row]
            
            cell.nameLabel.text = filter.name
            cell.imageView.image = image
            
            if currentFilter === filter {
                cell.nameLabel.textColor = .white
            } else {
                cell.nameLabel.textColor = RGB(160, 160, 160)
            }
            
            return cell
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == editToolCollectionView {
            let toolType = tools[indexPath.row]
            switch toolType {
            case .draw:
                drawBtnClick()
            case .clip:
                clipBtnClick()
            case .imageSticker:
                imageStickerBtnClick()
            case .textSticker:
                textStickerBtnClick()
            case .mosaic:
                mosaicBtnClick()
            case .filter:
                filterBtnClick()
            }
        } else if collectionView == drawColorCollectionView {
            currentDrawColor = drawColors[indexPath.row]
        } else {
            currentFilter = PhotoConfiguration.default().filters[indexPath.row]
            if let image = filterImages[currentFilter.name] {
                editImage = image
            } else {
                let image = currentFilter.applier?(originalImage) ?? originalImage
                editImage = image
                filterImages[currentFilter.name] = image
            }
            if tools.contains(.mosaic) {
                mosaicImage = editImage.mosaicImage()
                
                mosaicImageLayer?.removeFromSuperlayer()
                
                mosaicImageLayer = CALayer()
                mosaicImageLayer?.frame = imageView.bounds
                mosaicImageLayer?.contents = mosaicImage?.cgImage
                imageView.layer.insertSublayer(mosaicImageLayer!, below: mosaicImageLayerMaskLayer)
                
                mosaicImageLayer?.mask = mosaicImageLayerMaskLayer
                
                if mosaicPaths.isEmpty {
                    imageView.image = editImage
                } else {
                    generateNewMosaicImage()
                }
            } else {
                imageView.image = editImage
            }
        }
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        collectionView.reloadData()
    }
    
}

extension PBEditImageViewController: PBTextStickerViewDelegate {
    
    func stickerBeginOperation(_ sticker: UIView) {
        setToolView(show: false)
        ashbinView.layer.removeAllAnimations()
        ashbinView.isHidden = false
        var frame = ashbinView.frame
        let diff = view.frame.height - frame.minY
        frame.origin.y += diff
        ashbinView.frame = frame
        frame.origin.y -= diff
        UIView.animate(withDuration: 0.25) {
            self.ashbinView.frame = frame
        }
        
        stickersContainer.subviews.forEach { (view) in
            if view !== sticker {
                (view as? PBStickerViewAdditional)?.resetState()
                (view as? PBStickerViewAdditional)?.gesIsEnabled = false
            }
        }
    }
    
    func stickerOnOperation(_ sticker: UIView, panGes: UIPanGestureRecognizer) {
        let point = panGes.location(in: view)
        if ashbinView.frame.contains(point) {
            ashbinView.backgroundColor = RGB(241, 79, 79).withAlphaComponent(0.98)
            ashbinImgView.isHighlighted = true
            if sticker.alpha == 1 {
                sticker.layer.removeAllAnimations()
                UIView.animate(withDuration: 0.25) {
                    sticker.alpha = 0.5
                }
            }
        } else {
            ashbinView.backgroundColor = PBEditImageViewController.ashbinNormalBgColor
            ashbinImgView.isHighlighted = false
            if sticker.alpha != 1 {
                sticker.layer.removeAllAnimations()
                UIView.animate(withDuration: 0.25) {
                    sticker.alpha = 1
                }
            }
        }
    }
    
    func stickerEndOperation(_ sticker: UIView, panGes: UIPanGestureRecognizer) {
        setToolView(show: true)
        ashbinView.layer.removeAllAnimations()
        ashbinView.isHidden = true
        
        let point = panGes.location(in: view)
        if ashbinView.frame.contains(point) {
            (sticker as? PBStickerViewAdditional)?.moveToAshbin()
        }
        
        stickersContainer.subviews.forEach { (view) in
            (view as? PBStickerViewAdditional)?.gesIsEnabled = true
        }
    }
    
    func stickerDidTap(_ sticker: UIView) {
        stickersContainer.subviews.forEach { (view) in
            if view !== sticker {
                (view as? PBStickerViewAdditional)?.resetState()
            }
        }
    }
    
    func sticker(_ textSticker: PBTextStickerView, editText text: String) {
        showInputTextVC(text, textColor: textSticker.textColor, bgColor: textSticker.bgColor) { [weak self] (text, textColor, bgColor) in
            guard let `self` = self else { return }
            if text.isEmpty {
                textSticker.moveToAshbin()
            } else {
                textSticker.startTimer()
                guard textSticker.text != text || textSticker.textColor != textColor || textSticker.bgColor != bgColor else {
                    return
                }
                textSticker.text = text
                textSticker.textColor = textColor
                textSticker.bgColor = bgColor
                let newSize = PBTextStickerView.calculateSize(text: text, width: self.view.frame.width)
                textSticker.changeSize(to: newSize)
            }
        }
    }
    
}

func ==(lhs: PBImageClipRatio, rhs: PBImageClipRatio) -> Bool {
    return lhs.whRatio == rhs.whRatio
}

// MARK: Edit tool cell
class PBEditToolCell: UICollectionViewCell {
    
    var toolType: EditImageTool? {
        didSet {
            switch toolType {
            case .draw?:
                icon.image = getImage("pb_drawLine")
                icon.highlightedImage = getImage("pb_drawLine_selected")
            case .clip?:
                icon.image = getImage("pb_clip")
                icon.highlightedImage = getImage("pb_clip")
            case .imageSticker?:
                icon.image = getImage("pb_imageSticker")
                icon.highlightedImage = getImage("pb_imageSticker")
            case .textSticker?:
                icon.image = getImage("pb_textSticker")
                icon.highlightedImage = getImage("pb_textSticker")
            case .mosaic?:
                icon.image = getImage("pb_mosaic")
                icon.highlightedImage = getImage("pb_mosaic_selected")
            case .filter?:
                icon.image = getImage("pb_filter")
                icon.highlightedImage = getImage("pb_filter_selected")
            default:
                break
            }
        }
    }
    
    var icon: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        icon = UIImageView(frame: contentView.bounds)
        contentView.addSubview(icon)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


// MARK: draw color cell

class PBDrawColorCell: UICollectionViewCell {
    
    var bgWhiteView: UIView!
    
    var colorView: UIView!
    
    var color: UIColor! {
        didSet {
            colorView.backgroundColor = color
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        bgWhiteView = UIView()
        bgWhiteView.backgroundColor = .white
        bgWhiteView.layer.cornerRadius = 10
        bgWhiteView.layer.masksToBounds = true
        bgWhiteView.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        bgWhiteView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        contentView.addSubview(bgWhiteView)
        
        colorView = UIView()
        colorView.layer.cornerRadius = 8
        colorView.layer.masksToBounds = true
        colorView.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        colorView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        contentView.addSubview(colorView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


// MARK: filter cell
class PBFilterImageCell: UICollectionViewCell {
    
    var nameLabel: UILabel!
    
    var imageView: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        nameLabel = UILabel(frame: CGRect(x: 0, y: bounds.height-20, width: bounds.width, height: 20))
        nameLabel.font = UIFont.systemFont(ofSize: 12)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.layer.shadowColor = UIColor.black.withAlphaComponent(0.3).cgColor
        nameLabel.layer.shadowOffset = .zero
        nameLabel.layer.shadowOpacity = 1
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.5
        contentView.addSubview(nameLabel)
        
        imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.width))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


/// 涂鸦path
public class PBDrawPath: NSObject {
    
    let pathColor: UIColor
    
    let path: UIBezierPath
    
    let ratio: CGFloat
    
    let shapeLayer: CAShapeLayer
    
    init(pathColor: UIColor, pathWidth: CGFloat, ratio: CGFloat, startPoint: CGPoint) {
        self.pathColor = pathColor
        path = UIBezierPath()
        path.lineWidth = pathWidth / ratio
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: CGPoint(x: startPoint.x / ratio, y: startPoint.y / ratio))
        
        shapeLayer = CAShapeLayer()
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        shapeLayer.lineWidth = pathWidth / ratio
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = pathColor.cgColor
        shapeLayer.path = path.cgPath
        
        self.ratio = ratio
        
        super.init()
    }
    
    func addLine(to point: CGPoint) {
        path.addLine(to: CGPoint(x: point.x / ratio, y: point.y / ratio))
        shapeLayer.path = path.cgPath
    }
    
    func drawPath() {
        pathColor.set()
        path.stroke()
    }
}

/// 马赛克path
public class PBMosaicPath: NSObject {
    
    let path: UIBezierPath
    
    let ratio: CGFloat
    
    let startPoint: CGPoint
    
    var linePoints: [CGPoint] = []
    
    init(pathWidth: CGFloat, ratio: CGFloat, startPoint: CGPoint) {
        path = UIBezierPath()
        path.lineWidth = pathWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: startPoint)
        
        self.ratio = ratio
        self.startPoint = CGPoint(x: startPoint.x / ratio, y: startPoint.y / ratio)
        
        super.init()
    }
    
    func addLine(to point: CGPoint) {
        path.addLine(to: point)
        linePoints.append(CGPoint(x: point.x / ratio, y: point.y / ratio))
    }
    
}

