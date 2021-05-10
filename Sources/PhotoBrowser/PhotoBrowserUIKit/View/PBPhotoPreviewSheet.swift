//
//  PBPhotoPreviewSheet.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit
import Photos
import PhotoLib

@objcMembers
@objc(SwiftPBPhotoPreviewSheet)
open class PBPhotoPreviewSheet: UIView {

    struct Layout {
        
        static let colH: CGFloat = 155
        
        static let btnH: CGFloat = 45
        
        static let spacing: CGFloat = 1 / UIScreen.main.scale
        
    }
    
    private var baseView: UIView!
    
    private var collectionView: UICollectionView!
    
    private var cameraBtn: UIButton!
    
    private var photoLibraryBtn: UIButton!
    
    private var cancelBtn: UIButton!
    
    private var flexibleView: UIView!
    
    private var placeholderLabel: UILabel!
        
    private var arrDataSources: [PBPhotoModel] = []
    
    private var arrSelectedModels: [PBPhotoModel] = []
    
    private var preview = false
    
    private var animate = true
    
    private var senderTabBarIsHidden: Bool?
    
    private var baseViewHeight: CGFloat = 0
    
    private var isSelectOriginal = false
    
    private var panBeginPoint: CGPoint = .zero
    
    private var panImageView: UIImageView?
    
    private var panModel: PBPhotoModel?
    
    private var panCell: PBThumbnailPhotoCell?
    
    private weak var sender: UIViewController?
    
    private var fetchImageQueue: OperationQueue = OperationQueue()
    
    /// 框架回调
    /// 图片+Asset
    open var selectImageBlock: ( ([UIImage], [PHAsset], Bool) -> Void )?
    /// Asset
    open var selectAssetBlock: ( ([PHAsset], Bool) -> Void )?
    /// 图片获取失败 返回Asset
    open var selectImageRequestErrorBlock: ( ([PHAsset], [Int]) -> Void )?
    /// 取消
    open var cancelBlock: ( () -> Void )?
    
    public init(selectedAssets: [PHAsset] = []) {
        super.init(frame: .zero)
        
        if !PhotoConfiguration.default().allowSelectImage &&
            !PhotoConfiguration.default().allowSelectVideo {
//            assert(false, "PBPhotoBrowser: error configuration")
            PhotoConfiguration.default().allowSelectImage = true
        }
        
        fetchImageQueue.maxConcurrentOperationCount = 3
        setupUI()
        
        arrSelectedModels.removeAll()
        selectedAssets.removeDuplicate().forEach { (asset) in
            if !PhotoConfiguration.default().allowMixSelect, asset.mediaType == .video {
                return
            }
            
            let m = PBPhotoModel(asset: asset)
            m.isSelected = true
            arrSelectedModels.append(m)
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        baseView.frame = CGRect(x: 0, y: bounds.height - baseViewHeight, width: bounds.width, height: baseViewHeight)
        var btnY: CGFloat = 0
        if PhotoConfiguration.default().maxPreviewCount > 0 {
            collectionView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: PBPhotoPreviewSheet.Layout.colH)
            btnY += (collectionView.frame.maxY + PBPhotoPreviewSheet.Layout.spacing)
        }
        if canShowCameraBtn() {
            cameraBtn.frame = CGRect(x: 0, y: btnY, width: bounds.width, height: PBPhotoPreviewSheet.Layout.btnH)
            btnY += (PBPhotoPreviewSheet.Layout.btnH + PBPhotoPreviewSheet.Layout.spacing)
        }
        photoLibraryBtn.frame = CGRect(x: 0, y: btnY, width: bounds.width, height: PBPhotoPreviewSheet.Layout.btnH)
        btnY += (PBPhotoPreviewSheet.Layout.btnH + PBPhotoPreviewSheet.Layout.spacing)
        cancelBtn.frame = CGRect(x: 0, y: btnY, width: bounds.width, height: PBPhotoPreviewSheet.Layout.btnH)
        btnY += PBPhotoPreviewSheet.Layout.btnH
        flexibleView.frame = CGRect(x: 0, y: btnY, width: bounds.width, height: baseViewHeight - btnY)
    }
    
    func setupUI() {
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = .previewBgColor
        
        let showCameraBtn = canShowCameraBtn()
        var bh: CGFloat = 0
        if PhotoConfiguration.default().maxPreviewCount > 0 {
            bh += PBPhotoPreviewSheet.Layout.colH
        }
        bh += (PBPhotoPreviewSheet.Layout.spacing + PBPhotoPreviewSheet.Layout.btnH) * (showCameraBtn ? 3 : 2)
        bh += deviceSafeAreaInsets().bottom
        baseViewHeight = bh
        
        baseView = UIView()
        baseView.backgroundColor = RGB(230, 230, 230)
        addSubview(baseView)
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 3
        layout.minimumLineSpacing = 3
        layout.sectionInset = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .previewBtnBgColor
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isHidden = PhotoConfiguration.default().maxPreviewCount == 0
        PBThumbnailPhotoCell.register(collectionView)
        baseView.addSubview(collectionView)
        
        placeholderLabel = UILabel()
        placeholderLabel.font = UIFont.systemFont(ofSize: 15)
        placeholderLabel.text = "无照片"
        placeholderLabel.textAlignment = .center
        placeholderLabel.textColor = .previewBtnTitleColor
        collectionView.backgroundView = placeholderLabel
        
        func createBtn(_ title: String) -> UIButton {
            let btn = UIButton(type: .custom)
            btn.backgroundColor = .previewBtnBgColor
            btn.setTitleColor(.previewBtnTitleColor, for: .normal)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 17)
            return btn
        }
        
        let cameraTitle: String
        if !PhotoConfiguration.default().allowTakePhoto, PhotoConfiguration.default().allowRecordVideo {
            cameraTitle = "拍摄"
        } else {
            cameraTitle = "拍照"
        }
        cameraBtn = createBtn(cameraTitle)
        cameraBtn.isHidden = !showCameraBtn
        cameraBtn.addTarget(self, action: #selector(cameraBtnClick), for: .touchUpInside)
        baseView.addSubview(cameraBtn)
        
        photoLibraryBtn = createBtn("相册")
        photoLibraryBtn.addTarget(self, action: #selector(photoLibraryBtnClick), for: .touchUpInside)
        baseView.addSubview(photoLibraryBtn)
        
        cancelBtn = createBtn("取消")
        cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        baseView.addSubview(cancelBtn)
        
        flexibleView = UIView()
        flexibleView.backgroundColor = .previewBtnBgColor
        baseView.addSubview(flexibleView)
        
        if PhotoConfiguration.default().allowDragSelect {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(panSelectAction(_:)))
            baseView.addGestureRecognizer(pan)
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
    }
    
    func canShowCameraBtn() -> Bool {
        if !PhotoConfiguration.default().allowTakePhoto, !PhotoConfiguration.default().allowRecordVideo {
            return false
        }
        return true
    }
    
    
    /// 展示相册 跳转页面
    open func showPhotoLibrary(sender: UIViewController) {
        show(preview: false, animate: false, sender: sender)
    }
    
    /// 展示预览相册 底部弹出方式
    open func showPreview(animate: Bool = true, sender: UIViewController) {
        show(preview: true, animate: animate, sender: sender)
    }
    
    /// 传入已选择的assets，并直接跳到预览
    open func previewAssets(sender: UIViewController, assets: [PHAsset], index: Int, isOriginal: Bool, showBottomViewAndSelectBtn: Bool = true) {
        let models = assets.removeDuplicate().map { (asset) -> PBPhotoModel in
            let m = PBPhotoModel(asset: asset)
            m.isSelected = true
            return m
        }
        arrSelectedModels.removeAll()
        arrSelectedModels.append(contentsOf: models)
        self.sender = sender
        isSelectOriginal = isOriginal
        isHidden = true
        self.sender?.view.addSubview(self)
        
        let vc = PBPhotoPreviewController(photos: models, index: index, showBottomViewAndSelectBtn: showBottomViewAndSelectBtn)
        vc.autoSelectCurrentIfNotSelectAnyone = false
        let nav = getImageNav(rootViewController: vc)
        vc.backBlock = { [weak self] in
            self?.hide()
        }
        self.sender?.showDetailViewController(nav, sender: nil)
    }
    
    open func showCamera(sender: UIViewController) {
        let config = PhotoConfiguration.default()
        if config.useCustomCamera {
        let camera = PBCustomCamera()
            camera.selectImageBlock = { (model) in
                self.arrSelectedModels.append(model)
                self.requestSelectPhoto()
            }
            sender.showDetailViewController(camera, sender: nil)
        } else {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.allowsEditing = false
                picker.videoQuality = .typeHigh
                picker.sourceType = .camera
                picker.cameraFlashMode = config.cameraFlashMode.imagePickerFlashMode
                var mediaTypes = [String]()
                if config.allowTakePhoto {
                    mediaTypes.append("public.image")
                }
                if config.allowRecordVideo {
                    mediaTypes.append("public.movie")
                }
                picker.mediaTypes = mediaTypes
                picker.videoMaximumDuration = TimeInterval(config.maxRecordDuration)
                sender.showDetailViewController(picker, sender: nil)
            } else {
                showAlertView("相机不可用", sender)
            }
        }
    }
    
    func show(preview: Bool, animate: Bool, sender: UIViewController) {
        self.preview = preview
        self.animate = animate
        self.sender = sender
        
        let status = PBPhotoManager.authorizationStatus()
        if status == .restricted || status == .denied {
            showLibratyAuthority()
        } else if status == .notDetermined {
            PBPhotoManager.requestAuthorization { (status) in
                DispatchQueue.main.async {
                    if status == .denied {
                        self.showLibratyAuthority()
                    } else if status == .authorized {
                        if preview {
                            self.loadPhotos()
                            self.show()
                        } else {
                            self.photoLibraryBtnClick()
                        }
                    }
                }
            }
            
            self.sender?.view.addSubview(self)
        } else {
            if preview {
                loadPhotos()
                show()
            } else {
                self.sender?.view.addSubview(self)
                photoLibraryBtnClick()
            }
        }
        
        //iOS14 有限照片 监听相册更改
        if #available(iOS 14.0, *), preview, PBPhotoManager.authorizationStatus(for: .readWrite) == .limited {
            PBPhotoManager.register(self)
        }
    }
    
    func loadPhotos() {
        arrDataSources.removeAll()
        
        let config = PhotoConfiguration.default()
        PBPhotoModelManager.getCameraRollAlbum(allowSelectImage: config.allowSelectImage, allowSelectVideo: config.allowSelectVideo) { [weak self] (cameraRoll) in
            guard let `self` = self else { return }
            var totalPhotos = PBPhotoModelManager.fetchPhoto(in: cameraRoll.result, ascending: false, allowSelectImage: config.allowSelectImage, allowSelectVideo: config.allowSelectVideo, limitCount: config.maxPreviewCount)
            markSelected(source: &totalPhotos, selected: &self.arrSelectedModels)
            self.arrDataSources.append(contentsOf: totalPhotos)
            self.collectionView.reloadData()
        }
    }
    
    func show() {
        frame = sender?.view.bounds ?? .zero
        
        collectionView.contentOffset = .zero
        
        if superview == nil {
            sender?.view.addSubview(self)
        }
        
        if let tabBar = sender?.tabBarController?.tabBar, !tabBar.isHidden {
            senderTabBarIsHidden = tabBar.isHidden
            tabBar.isHidden =  true
        }
        
        if animate {
            backgroundColor = UIColor.previewBgColor.withAlphaComponent(0)
            var frame = baseView.frame
            frame.origin.y = bounds.height
            baseView.frame = frame
            UIView.animate(withDuration: 0.2) {
                self.backgroundColor = UIColor.previewBgColor
                frame.origin.y -= self.baseViewHeight
                self.baseView.frame = frame
            }
        }
    }
    
    func hide() {
        if animate {
            var frame = baseView.frame
            frame.origin.y += baseViewHeight
            UIView.animate(withDuration: 0.2, animations: {
                self.backgroundColor = UIColor.previewBgColor.withAlphaComponent(0)
                self.baseView.frame = frame
            }) { (_) in
                self.isHidden = true
                self.removeFromSuperview()
            }
        } else {
            isHidden = true
            removeFromSuperview()
        }
        
        if let temp = senderTabBarIsHidden {
            sender?.tabBarController?.tabBar.isHidden = temp
        }
    }
    
    func showLibratyAuthority() {
        let authorityController = PBPhotoAuthorityController()
        authorityController.modalPresentationStyle = .fullScreen
        sender?.present(authorityController, animated: true, completion: nil)
    }
    
    @objc func tapAction(_ tap: UITapGestureRecognizer) {
        cancelBlock?()
        hide()
    }
    
    
    
    @objc func cameraBtnClick() {
        let config = PhotoConfiguration.default()
        if config.useCustomCamera {
            let camera = PBCustomCamera()
            camera.takeDoneBlock = { [weak self] (image, videoUrl) in
                self?.save(image: image, videoUrl: videoUrl)
            }
            sender?.showDetailViewController(camera, sender: nil)
        } else {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.allowsEditing = false
                picker.videoQuality = .typeHigh
                picker.sourceType = .camera
                picker.cameraFlashMode = config.cameraFlashMode.imagePickerFlashMode
                var mediaTypes = [String]()
                if config.allowTakePhoto {
                    mediaTypes.append("public.image")
                }
                if config.allowRecordVideo {
                    mediaTypes.append("public.movie")
                }
                picker.mediaTypes = mediaTypes
                picker.videoMaximumDuration = TimeInterval(config.maxRecordDuration)
                sender?.showDetailViewController(picker, sender: nil)
            } else {
                showAlertView("相机不可用", sender)
            }
        }
    }
    
    @objc func photoLibraryBtnClick() {
        PBPhotoManager.unregisterChangeObserver(self)
        animate = false
        showThumbnailViewController()
    }
    
    @objc func cancelBtnClick() {
        guard !arrSelectedModels.isEmpty else {
            cancelBlock?()
            hide()
            return
        }
        requestSelectPhoto()
    }
    
    @objc func panSelectAction(_ pan: UIPanGestureRecognizer) {
        let point = pan.location(in: collectionView)
        if pan.state == .began {
            let cp = baseView.convert(point, from: collectionView)
            guard collectionView.frame.contains(cp) else {
                panBeginPoint = .zero
                return
            }
            panBeginPoint = point
        } else if pan.state == .changed {
            guard panBeginPoint != .zero else {
                return
            }
            
            guard let indexPath = collectionView.indexPathForItem(at: panBeginPoint) else {
                return
            }
            
            if panImageView == nil {
                guard point.y < panBeginPoint.y else {
                    return
                }
                guard let cell = collectionView.cellForItem(at: indexPath) as? PBThumbnailPhotoCell else {
                    return
                }
                panModel = arrDataSources[indexPath.row]
                panCell = cell
                panImageView = UIImageView(frame: cell.bounds)
                panImageView?.contentMode = .scaleAspectFill
                panImageView?.clipsToBounds = true
                panImageView?.image = cell.imageView.image
                cell.imageView.image = nil
                addSubview(panImageView!)
            }
            panImageView?.center = convert(point, from: collectionView)
        } else if pan.state == .cancelled || pan.state == .ended {
            guard let pv = panImageView else {
                return
            }
            let pvRect = baseView.convert(pv.frame, from: self)
            var callBack = false
            if pvRect.midY < -10 {
                arrSelectedModels.removeAll()
                arrSelectedModels.append(panModel!)
                requestSelectPhoto()
                callBack = true
            }
            
            panModel = nil
            if !callBack {
                let toRect = convert(panCell?.frame ?? .zero, from: collectionView)
                UIView.animate(withDuration: 0.25, animations: {
                    self.panImageView?.frame = toRect
                }) { (_) in
                    self.panCell?.imageView.image = self.panImageView?.image
                    self.panCell = nil
                    self.panImageView?.removeFromSuperview()
                    self.panImageView = nil
                }
            } else {
                panCell?.imageView.image = panImageView?.image
                panImageView?.removeFromSuperview()
                panImageView = nil
                panCell = nil
            }
        }
    }
    
    func requestSelectPhoto(viewController: UIViewController? = nil) {
        guard !arrSelectedModels.isEmpty else {
            selectAssetBlock?([], isSelectOriginal)
            selectImageBlock?([], [], isSelectOriginal)
            hide()
            viewController?.dismiss(animated: true, completion: nil)
            return
        }
        
        let config = PhotoConfiguration.default()
        
        if config.allowMixSelect {
            let videoCount = arrSelectedModels.filter { $0.type == .video }.count
            
            if videoCount > config.maxVideoSelectCount {
                showAlertView(String(format: "最多只能选择%ld个视频", PhotoConfiguration.default().maxVideoSelectCount), viewController)
                return
            } else if videoCount < config.minVideoSelectCount {
                showAlertView(String(format: "最少选择%ld个视频", PhotoConfiguration.default().minVideoSelectCount), viewController)
                return
            }
        }
        
        let hud = PBProgressHUD(style: PhotoConfiguration.default().hudStyle)
        
        var timeout = false
        hud.timeoutBlock = { [weak self] in
            timeout = true
            showAlertView("请求超时", viewController ?? self?.sender)
            self?.fetchImageQueue.cancelAllOperations()
        }
        
        hud.show(timeout: PhotoConfiguration.default().timeout)
        
        guard (selectImageBlock != nil) else {
            hud.hide()
            selectAssetBlock?(arrSelectedModels.map { $0.asset }, isSelectOriginal)
            arrSelectedModels.removeAll()
            hide()
            viewController?.dismiss(animated: true, completion: nil)
            return
        }
        
        guard PhotoConfiguration.default().shouldAnialysisAsset else {
            hud.hide()
            selectImageBlock?([], arrSelectedModels.map { $0.asset }, isSelectOriginal)
            selectAssetBlock?(arrSelectedModels.map { $0.asset }, isSelectOriginal)
            arrSelectedModels.removeAll()
            hide()
            viewController?.dismiss(animated: true, completion: nil)
            return
        }
        
        var images: [UIImage?] = Array(repeating: nil, count: arrSelectedModels.count)
        var assets: [PHAsset?] = Array(repeating: nil, count: arrSelectedModels.count)
        var errorAssets: [PHAsset] = []
        var errorIndexs: [Int] = []
        
        var sucCount = 0
        let totalCount = arrSelectedModels.count
        for (i, m) in arrSelectedModels.enumerated() {
            let operation = PBFetchImageOperation(model: m, isOriginal: isSelectOriginal) { [weak self] (image, asset) in
                guard !timeout else { return }
                
                sucCount += 1
                
                if let image = image {
                    images[i] = image
                    assets[i] = asset ?? m.asset
                } else {
                    errorAssets.append(m.asset)
                    errorIndexs.append(i)
                }
                
                guard sucCount >= totalCount else { return }
                let sucImages = images.compactMap { $0 }
                let sucAssets = assets.compactMap { $0 }
                hud.hide()
                
                self?.selectImageBlock?(sucImages, sucAssets, self?.isSelectOriginal ?? false)
                self?.selectAssetBlock?(sucAssets, self?.isSelectOriginal ?? false)
                self?.arrSelectedModels.removeAll()
                if !errorAssets.isEmpty {
                    self?.selectImageRequestErrorBlock?(errorAssets, errorIndexs)
                }
                self?.arrDataSources.removeAll()
                self?.hide()
                viewController?.dismiss(animated: true, completion: nil)
            }
            fetchImageQueue.addOperation(operation)
        }
    }
    
    func showThumbnailViewController() {
        PBPhotoModelManager.getCameraRollAlbum(allowSelectImage: PhotoConfiguration.default().allowSelectImage, allowSelectVideo: PhotoConfiguration.default().allowSelectVideo) { [weak self] (cameraRoll) in
            guard let `self` = self else { return }
            let nav: PBImageNavController
            if PhotoConfiguration.default().style == .embedAlbumList {
                let tvc = PBThumbnailViewController(albumList: cameraRoll)
                nav = self.getImageNav(rootViewController: tvc)
            } else {
                nav = self.getImageNav(rootViewController: PBAlbumListController())
                let tvc = PBThumbnailViewController(albumList: cameraRoll)
                nav.pushViewController(tvc, animated: true)
            }
            self.sender?.showDetailViewController(nav, sender: nil)
        }
    }
    
    func showPreviewController(_ models: [PBPhotoModel], index: Int) {
        let vc = PBPhotoPreviewController(photos: models, index: index)
        let nav = getImageNav(rootViewController: vc)
        vc.backBlock = { [weak self, weak nav] in
            guard let `self` = self else { return }
            self.isSelectOriginal = nav?.isSelectedOriginal ?? false
            self.arrSelectedModels.removeAll()
            self.arrSelectedModels.append(contentsOf: nav?.arrSelectedModels ?? [])
            markSelected(source: &self.arrDataSources, selected: &self.arrSelectedModels)
            self.collectionView.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
            self.changeCancelBtnTitle()
        }
        sender?.showDetailViewController(nav, sender: nil)
    }
    
    func showEditImageVC(model: PBPhotoModel) {
        let hud = PBProgressHUD(style: PhotoConfiguration.default().hudStyle)
        hud.show()
        
        PBPhotoManager.fetchImage(for: model.asset, size: model.previewSize) { [weak self] (image, isDegraded) in
            if !isDegraded {
                if let image = image {
                    PBEditImageViewController.showEditImageVC(parentVC: self?.sender, image: image, editModel: model.editImageModel) { [weak self] (ei, editImageModel) in
                        model.isSelected = true
                        model.editImage = ei
                        model.editImageModel = editImageModel
                        self?.arrSelectedModels.append(model)
                        self?.requestSelectPhoto()
                    }
                } else {
                    showAlertView("图片加载失败", self?.sender)
                }
                hud.hide()
            }
        }
    }
    
    func showEditVideoVC(model: PBPhotoModel) {
        let hud = PBProgressHUD(style: PhotoConfiguration.default().hudStyle)
        
        var requestAvAssetID: PHImageRequestID?
        
        hud.show(timeout: 20)
        hud.timeoutBlock = { [weak self] in
            showAlertView("请求超时", self?.sender)
            if let _ = requestAvAssetID {
                PHImageManager.default().cancelImageRequest(requestAvAssetID!)
            }
        }
        
        func inner_showEditVideoVC(_ avAsset: AVAsset) {
            let vc = PBEditVideoViewController(avAsset: avAsset)
            vc.editFinishBlock = { [weak self] (url) in
                if let u = url {
                    PBPhotoManager.saveVideoToAlbum(url: u) { [weak self] (suc, asset) in
                        if suc, asset != nil {
                            let m = PBPhotoModel(asset: asset!)
                            m.isSelected = true
                            self?.arrSelectedModels.removeAll()
                            self?.arrSelectedModels.append(m)
                            self?.requestSelectPhoto()
                        } else {
                            showAlertView("视频保存失败", self?.sender)
                        }
                    }
                } else {
                    self?.arrSelectedModels.removeAll()
                    self?.arrSelectedModels.append(model)
                    self?.requestSelectPhoto()
                }
            }
            vc.modalPresentationStyle = .fullScreen
            sender?.showDetailViewController(vc, sender: nil)
        }
        
        // 提前fetch一下 avasset
        requestAvAssetID = PBPhotoManager.fetchAVAsset(forVideo: model.asset) { [weak self] (avAsset, _) in
            hud.hide()
            if let _ = avAsset {
                inner_showEditVideoVC(avAsset!)
            } else {
                showAlertView("请求超时", self?.sender)
            }
        }
    }
    
    func getImageNav(rootViewController: UIViewController) -> PBImageNavController {
        let nav = PBImageNavController(rootViewController: rootViewController)
        nav.modalPresentationStyle = .fullScreen
        nav.selectImageBlock = { [weak self, weak nav] in
            self?.isSelectOriginal = nav?.isSelectedOriginal ?? false
            self?.arrSelectedModels.removeAll()
            self?.arrSelectedModels.append(contentsOf: nav?.arrSelectedModels ?? [])
            self?.requestSelectPhoto(viewController: nav)
        }
        
        nav.cancelBlock = { [weak self] in
            self?.cancelBlock?()
            self?.hide()
        }
        nav.isSelectedOriginal = isSelectOriginal
        nav.arrSelectedModels.removeAll()
        nav.arrSelectedModels.append(contentsOf: arrSelectedModels)
        
        return nav
    }
    
    func save(image: UIImage?, videoUrl: URL?) {
        let hud = PBProgressHUD(style: PhotoConfiguration.default().hudStyle)
        if let image = image {
            hud.show()
            PBPhotoManager.saveImageToAlbum(image: image) { [weak self] (suc, asset) in
                if suc, let at = asset {
                    let model = PBPhotoModel(asset: at)
                    self?.handleDataArray(newModel: model)
                } else {
                    showAlertView("保存图片失败", self?.sender)
                }
                hud.hide()
            }
        } else if let videoUrl = videoUrl {
            hud.show()
            PBPhotoManager.saveVideoToAlbum(url: videoUrl) { [weak self] (suc, asset) in
                if suc, let at = asset {
                    let model = PBPhotoModel(asset: at)
                    self?.handleDataArray(newModel: model)
                } else {
                    showAlertView("保存视频失败", self?.sender)
                }
                hud.hide()
            }
        }
    }
    
    func handleDataArray(newModel: PBPhotoModel) {
        arrDataSources.insert(newModel, at: 0)
        
        var canSelect = true
        // If mixed selection is not allowed, and the newModel type is video, it will not be selected.
        if !PhotoConfiguration.default().allowMixSelect, newModel.type == .video {
            canSelect = false
        }
        if canSelect, canAddModel(newModel, currentSelectCount: arrSelectedModels.count, sender: sender, showAlert: false) {
            if !shouldDirectEdit(newModel) {
                newModel.isSelected = true
                arrSelectedModels.append(newModel)
            }
        }
        
        let insertIndexPath = IndexPath(row: 0, section: 0)
        collectionView.performBatchUpdates({
            collectionView.insertItems(at: [insertIndexPath])
        }) { (_) in
            self.collectionView.scrollToItem(at: insertIndexPath, at: .centeredHorizontally, animated: true)
            self.collectionView.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
        }
        
        changeCancelBtnTitle()
    }
    
}


extension PBPhotoPreviewSheet: UIGestureRecognizerDelegate {
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: self)
        return !baseView.frame.contains(location)
    }
    
}


extension PBPhotoPreviewSheet: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let m = arrDataSources[indexPath.row]
        let w = CGFloat(m.asset.pixelWidth)
        let h = CGFloat(m.asset.pixelHeight)
        let scale = min(1.7, max(0.5, w / h))
        return CGSize(width: collectionView.frame.height * scale, height: collectionView.frame.height)
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        placeholderLabel.isHidden = !arrDataSources.isEmpty
        return arrDataSources.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PBThumbnailPhotoCell.identifier(), for: indexPath) as! PBThumbnailPhotoCell
        
        let model = arrDataSources[indexPath.row]
        
        cell.selectedBlock = { [weak self, weak cell] (isSelected) in
            guard let `self` = self else { return }
            if !isSelected {
                guard canAddModel(model, currentSelectCount: self.arrSelectedModels.count, sender: self.sender) else {
                    return
                }
                if !self.shouldDirectEdit(model) {
                    model.isSelected = true
                    self.arrSelectedModels.append(model)
                    cell?.btnSelect.isSelected = true
                    self.refreshCellIndex()
                }
            } else {
                cell?.btnSelect.isSelected = false
                model.isSelected = false
                self.arrSelectedModels.removeAll { $0 == model }
                self.refreshCellIndex()
            }
            
            self.changeCancelBtnTitle()
        }
        
        cell.indexLabel.isHidden = true
        if PhotoConfiguration.default().showSelectedIndex {
            for (index, selM) in arrSelectedModels.enumerated() {
                if model == selM {
                    setCellIndex(cell, showIndexLabel: true, index: index + 1, animate: false)
                    break
                }
            }
        }
        
        setCellMaskView(cell, isSelected: model.isSelected, model: model)
        
        cell.model = model
        
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let c = cell as? PBThumbnailPhotoCell else {
            return
        }
        let model = arrDataSources[indexPath.row]
        setCellMaskView(c, isSelected: model.isSelected, model: model)
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? PBThumbnailPhotoCell else {
            return
        }
        
        if !PhotoConfiguration.default().allowPreviewPhotos {
            cell.btnSelectClick()
            return
        }
        
        if !cell.enableSelect, PhotoConfiguration.default().showInvalidMask {
            return
        }
        let model = arrDataSources[indexPath.row]
        
        if shouldDirectEdit(model) {
            return
        }
        let config = PhotoConfiguration.default()
        let hud = PBProgressHUD(style: config.hudStyle)
        hud.show()
        
        PBPhotoModelManager.getCameraRollAlbum(allowSelectImage: config.allowSelectImage, allowSelectVideo: config.allowSelectVideo) { [weak self] (cameraRoll) in
            guard let `self` = self else {
                hud.hide()
                return
            }
            var totalPhotos = PBPhotoModelManager.fetchPhoto(in: cameraRoll.result, ascending: config.sortAscending, allowSelectImage: config.allowSelectImage, allowSelectVideo: config.allowSelectVideo)
            markSelected(source: &totalPhotos, selected: &self.arrSelectedModels)
            let defaultIndex = config.sortAscending ? totalPhotos.count - 1 : 0
            var index: Int?
            // last和first效果一样，只是排序方式不同时候分别从前后开始查找可以更快命中
            if config.sortAscending {
                index = totalPhotos.lastIndex { $0 == model }
            } else {
                index = totalPhotos.firstIndex { $0 == model }
            }
            hud.hide()
            
            self.showPreviewController(totalPhotos, index: index ?? defaultIndex)
        }
    }
    
    func shouldDirectEdit(_ model: PBPhotoModel) -> Bool {
        let config = PhotoConfiguration.default()
        
        let canEditImage = config.editAfterSelectThumbnailImage &&
            config.allowEditImage &&
            config.maxSelectCount == 1 &&
            model.type.rawValue < PBPhotoModel.MediaType.video.rawValue
        
        let canEditVideo = (config.editAfterSelectThumbnailImage &&
            config.allowEditVideo &&
            model.type == .video &&
            config.maxSelectCount == 1) ||
            (config.allowEditVideo &&
            model.type == .video &&
            !config.allowMixSelect &&
            config.cropVideoAfterSelectThumbnail)
        
        //当前未选择图片 或已经选择了一张并且点击的是已选择的图片
        let flag = arrSelectedModels.isEmpty || (arrSelectedModels.count == 1 && arrSelectedModels.first?.ident == model.ident)
        
        if canEditImage, flag {
            showEditImageVC(model: model)
        } else if canEditVideo, flag {
            showEditVideoVC(model: model)
        }
        
        return flag && (canEditImage || canEditVideo)
    }
    
    func setCellIndex(_ cell: PBThumbnailPhotoCell?, showIndexLabel: Bool, index: Int, animate: Bool) {
        guard PhotoConfiguration.default().showSelectedIndex else {
            return
        }
        cell?.index = index
        cell?.indexLabel.isHidden = !showIndexLabel
        if animate {
            cell?.indexLabel.layer.add(getSpringAnimation(), forKey: nil)
        }
    }
    
    func refreshCellIndex() {
        let showIndex = PhotoConfiguration.default().showSelectedIndex
        let showMask = PhotoConfiguration.default().showSelectedMask || PhotoConfiguration.default().showInvalidMask
        
        guard showIndex || showMask else {
            return
        }
        
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        
        visibleIndexPaths.forEach { (indexPath) in
            guard let cell = collectionView.cellForItem(at: indexPath) as? PBThumbnailPhotoCell else {
                return
            }
            let m = arrDataSources[indexPath.row]
            
            var show = false
            var idx = 0
            var isSelected = false
            for (index, selM) in arrSelectedModels.enumerated() {
                if m == selM {
                    show = true
                    idx = index + 1
                    isSelected = true
                    break
                }
            }
            if showIndex {
                setCellIndex(cell, showIndexLabel: show, index: idx, animate: false)
            }
            if showMask {
                setCellMaskView(cell, isSelected: isSelected, model: m)
            }
        }
    }
    
    func setCellMaskView(_ cell: PBThumbnailPhotoCell, isSelected: Bool, model: PBPhotoModel) {
        cell.coverView.isHidden = true
        cell.enableSelect = true
        let config = PhotoConfiguration.default()
        
        if isSelected {
            cell.coverView.backgroundColor = .selectedMaskColor
            cell.coverView.isHidden = !config.showSelectedMask
            if config.showSelectedBorder {
                cell.layer.borderWidth = 4
            }
        } else {
            let selCount = arrSelectedModels.count
            if selCount < config.maxSelectCount {
                if config.allowMixSelect {
                    let videoCount = arrSelectedModels.filter { $0.type == .video }.count
                    if videoCount >= config.maxVideoSelectCount, model.type == .video {
                        cell.coverView.backgroundColor = .invalidMaskColor
                        cell.coverView.isHidden = !config.showInvalidMask
                        cell.enableSelect = false
                    } else if (config.maxSelectCount - selCount) <= (config.minVideoSelectCount - videoCount), model.type != .video {
                        cell.coverView.backgroundColor = .invalidMaskColor
                        cell.coverView.isHidden = !config.showInvalidMask
                        cell.enableSelect = false
                    }
                } else if selCount > 0 {
                    cell.coverView.backgroundColor = .invalidMaskColor
                    cell.coverView.isHidden = (!config.showInvalidMask || model.type != .video)
                    cell.enableSelect = model.type != .video
                }
            } else if selCount >= config.maxSelectCount {
                cell.coverView.backgroundColor = .invalidMaskColor
                cell.coverView.isHidden = !config.showInvalidMask
                cell.enableSelect = false
            }
            if config.showSelectedBorder {
                cell.layer.borderWidth = 0
            }
        }
    }
    
    func changeCancelBtnTitle() {
        if arrSelectedModels.count > 0 {
            cancelBtn.setTitle(String(format: "确定(%ld)", arrSelectedModels.count), for: .normal)
            cancelBtn.setTitleColor(.previewBtnHighlightTitleColor, for: .normal)
        } else {
            cancelBtn.setTitle("取消", for: .normal)
            cancelBtn.setTitleColor(.previewBtnTitleColor, for: .normal)
        }
    }
    
}


extension PBPhotoPreviewSheet: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) {
            let image = info[.originalImage] as? UIImage
            let url = info[.mediaURL] as? URL
            self.save(image: image, videoUrl: url)
        }
    }
    
}


extension PBPhotoPreviewSheet: PHPhotoLibraryChangeObserver {
    
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        PBPhotoManager.unregisterChangeObserver(self)
        DispatchQueue.main.async {
            self.loadPhotos()
        }
    }
    
}
