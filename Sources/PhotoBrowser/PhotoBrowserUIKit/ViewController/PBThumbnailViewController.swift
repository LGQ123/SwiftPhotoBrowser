//
//  PBThumbnailViewController.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit
import Photos
import PhotoLib
extension PBThumbnailViewController {
    
    enum SlideSelectType {
        
        case none
        
        case select
        
        case cancel
        
    }
    
}

class PBThumbnailViewController: UIViewController {

    var albumList: PBAlbumListModel
    
    var externalNavView: PBExternalAlbumListNavView?
    
    var embedNavView: PBEmbedAlbumListNavView?
    
    var embedAlbumListView: PBEmbedAlbumListView?
    
    var collectionView: UICollectionView!
    
    var bottomView: UIView!
    
    var bottomBlurView: UIVisualEffectView?
    
    var previewBtn: UIButton!
    
    var originalBtn: UIButton!
    
    var doneBtn: UIButton!
    
    var arrDataSources: [PBPhotoModel] = []
    
    var showCameraCell: Bool {
        if PhotoConfiguration.default().allowTakePhotoInLibrary && albumList.isCameraRoll {
            return true
        }
        return false
    }
    
    /// 所有滑动经过的indexPath
    lazy var arrSlideIndexPaths: [IndexPath] = []
    
    /// 所有滑动经过的indexPath的初始选择状态
    lazy var dicOriSelectStatus: [IndexPath: Bool] = [:]
    
    var isLayoutOK = false
    
    /// 设备旋转前第一个可视indexPath
    var firstVisibleIndexPathBeforeRotation: IndexPath?
    
    /// 是否触发了横竖屏切换
    var isSwitchOrientation = false
    
    /// 是否开始出发滑动选择
    var beginPanSelect = false
    
    /// 滑动选择 或 取消
    /// 当初始滑动的cell处于未选择状态，则开始选择，反之，则开始取消选择
    var panSelectType: PBThumbnailViewController.SlideSelectType = .none
    
    /// 开始滑动的indexPath
    var beginSlideIndexPath: IndexPath?
    
    /// 最后滑动经过的index，开始的indexPath不计入
    /// 优化拖动手势计算，避免单个cell中冗余计算多次
    var lastSlideIndex: Int?
    
    /// 预览所选择图片，手势返回时候不调用scrollToIndex
    var isPreviewPush = false
    
    /// 拍照后置为true，需要刷新相册列表
    var hasTakeANewAsset = false
    
    var slideCalculateQueue = DispatchQueue(label: "com.PBhotoBrowser.slide")
    
    var autoScrollTimer: CADisplayLink?
    
    var lastPanUpdateTime = CACurrentMediaTime()
    
    private enum AutoScrollDirection {
        case none
        case top
        case bottom
    }
    
    private var autoScrollInfo: (direction: AutoScrollDirection, speed: CGFloat) = (.none, 0)
    
    @available(iOS 14, *)
    var showAddPhotoCell: Bool {
        PBPhotoManager.authorizationStatus(for: .readWrite) == .limited && PhotoConfiguration.default().showAddPhotoButton && albumList.isCameraRoll
    }
    
    /// 照相按钮+添加图片按钮的数量
    /// the count of addPhotoButton & cameraButton
    private var offset: Int {
        if #available(iOS 14, *) {
            return Int(showAddPhotoCell) + Int(showCameraCell)
        } else {
            return Int(showCameraCell)
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return PhotoConfiguration.default().statusBarStyle
    }
    
    var panGes: UIPanGestureRecognizer!
    
    init(albumList: PBAlbumListModel) {
        self.albumList = albumList
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        
        if PhotoConfiguration.default().allowSlideSelect {
            panGes = UIPanGestureRecognizer(target: self, action: #selector(slideSelectAction(_:)))
            view.addGestureRecognizer(panGes)
        }
        
        loadPhotos()
        
        // 注册相册更改通知
        if #available(iOS 14.0, *), PBPhotoManager.authorizationStatus(for: .readWrite) == .limited {
            PBPhotoManager.register(self)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
        resetBottomToolBtnStatus()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isLayoutOK = true
        isPreviewPush = false
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let pInView = collectionView.convert(CGPoint(x: 100, y: 100), from: view)
        firstVisibleIndexPathBeforeRotation = collectionView.indexPathForItem(at: pInView)
        isSwitchOrientation = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let navViewNormalH: CGFloat = 44
        
        var insets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        var collectionViewInsetTop: CGFloat = 20
        if #available(iOS 11.0, *) {
            insets = view.safeAreaInsets
            collectionViewInsetTop = navViewNormalH
        } else {
            collectionViewInsetTop += navViewNormalH
        }
        
        let navViewFrame = CGRect(x: 0, y: 0, width: view.frame.width, height: insets.top + navViewNormalH)
        externalNavView?.frame = navViewFrame
        embedNavView?.frame = navViewFrame
        
        embedAlbumListView?.frame = CGRect(x: 0, y: navViewFrame.maxY, width: view.bounds.width, height: view.bounds.height-navViewFrame.maxY)
        
        var showBottomView = true
        
        let config = PhotoConfiguration.default()
        let condition1 = config.editAfterSelectThumbnailImage &&
            config.maxSelectCount == 1 &&
            (config.allowEditImage || config.allowEditVideo)
        let condition2 = config.maxSelectCount == 1 && !config.showSelectBtnWhenSingleSelect
        if condition1 || condition2 {
            showBottomView = false
            insets.bottom = 0
        }
        let bottomViewH = showBottomView ? PBLayout.bottomToolViewH : 0
        
        let totalWidth = view.frame.width - insets.left - insets.right
        collectionView.frame = CGRect(x: insets.left, y: 0, width: totalWidth, height: view.frame.height)
        collectionView.contentInset = UIEdgeInsets(top: collectionViewInsetTop, left: 0, bottom: bottomViewH, right: 0)
        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: insets.top, left: 0, bottom: bottomViewH, right: 0)
        
        if !isLayoutOK {
            scrollToBottom()
        } else if isSwitchOrientation {
            isSwitchOrientation = false
            if let ip = firstVisibleIndexPathBeforeRotation {
                collectionView.scrollToItem(at: ip, at: .top, animated: false)
            }
        }
        
        guard showBottomView else { return }
        
        let btnH = PBLayout.bottomToolBtnH
        
        bottomView.frame = CGRect(x: 0, y: view.frame.height-insets.bottom-bottomViewH, width: view.bounds.width, height: bottomViewH+insets.bottom)
        bottomBlurView?.frame = bottomView.bounds
        
        let btnY: CGFloat = 7
        
//        let previewTitle = "预览"
        let previewBtnW: CGFloat = 40.0
        previewBtn.frame = CGRect(x: 15, y: btnY, width: previewBtnW, height: btnH)
        
//        let originalTitle = "原图"
        let originBtnW: CGFloat = 70.0
        originalBtn.frame = CGRect(x: (bottomView.bounds.width-originBtnW)/2-5, y: btnY, width: originBtnW, height: btnH)
        
        refreshDoneBtnFrame()
    }
    
    func setupUI() {
        edgesForExtendedLayout = .all
        view.backgroundColor = .thumbnailBgColor
        
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 3, left: 0, bottom: 3, right: 0)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .thumbnailBgColor
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        if #available(iOS 11.0, *) {
            collectionView.contentInsetAdjustmentBehavior = .always
        } else {
            automaticallyAdjustsScrollViewInsets = true
        }
        view.addSubview(collectionView)
        
        PBCameraCell.pb_register(collectionView)
        PBThumbnailPhotoCell.pb_register(collectionView)
        collectionView.register(PBThumbnailColViewFooter.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: NSStringFromClass(PBThumbnailColViewFooter.classForCoder()))
        PBAddPhotoCell.pb_register(collectionView)
        
        bottomView = UIView()
        bottomView.backgroundColor = .bottomToolViewBgColor
        view.addSubview(bottomView)
        
        if let effect = PhotoConfiguration.default().bottomToolViewBlurEffect {
            bottomBlurView = UIVisualEffectView(effect: effect)
            bottomView.addSubview(bottomBlurView!)
        }
        
        func createBtn(_ title: String, _ action: Selector) -> UIButton {
            let btn = UIButton(type: .custom)
            btn.titleLabel?.font = PBLayout.bottomToolTitleFont
            btn.setTitle(title, for: .normal)
            btn.setTitleColor(.bottomToolViewBtnNormalTitleColor, for: .normal)
            btn.setTitleColor(.bottomToolViewBtnDisableTitleColor, for: .disabled)
            btn.addTarget(self, action: action, for: .touchUpInside)
            return btn
        }
        
        previewBtn = createBtn("预览", #selector(previewBtnClick))
        previewBtn.isHidden = !PhotoConfiguration.default().showPreviewButtonInAlbum
        bottomView.addSubview(previewBtn)
        
        originalBtn = createBtn("原图", #selector(originalPhotoClick))
        originalBtn.setImage(getImage("pb_btn_original_circle"), for: .normal)
        originalBtn.setImage(getImage("pb_btn_original_selected"), for: .selected)
        originalBtn.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        originalBtn.isHidden = !(PhotoConfiguration.default().allowSelectOriginal && PhotoConfiguration.default().allowSelectImage)
        originalBtn.isSelected = (navigationController as! PBImageNavController).isSelectedOriginal
        bottomView.addSubview(originalBtn)
        
        doneBtn = createBtn("完成", #selector(doneBtnClick))
        doneBtn.layer.masksToBounds = true
        doneBtn.layer.cornerRadius = PBLayout.bottomToolBtnCornerRadius
        bottomView.addSubview(doneBtn)
        
        setupNavView()
    }
    
    func setupNavView() {
        if PhotoConfiguration.default().style == .embedAlbumList {
            embedNavView = PBEmbedAlbumListNavView(title: albumList.title)
            
            embedNavView?.selectAlbumBlock = { [weak self] in
                if self?.embedAlbumListView?.isHidden == true {
                    self?.embedAlbumListView?.show(reloadAlbumList: self?.hasTakeANewAsset ?? false)
                    self?.hasTakeANewAsset = false
                } else {
                    self?.embedAlbumListView?.hide()
                }
            }
            
            embedNavView?.cancelBlock = { [weak self] in
                let nav = self?.navigationController as? PBImageNavController
                nav?.cancelBlock?()
                nav?.dismiss(animated: true, completion: nil)
            }
            
            view.addSubview(embedNavView!)
            
            embedAlbumListView = PBEmbedAlbumListView(selectedAlbum: albumList)
            embedAlbumListView?.isHidden = true
            
            embedAlbumListView?.selectAlbumBlock = { [weak self] (album) in
                guard self?.albumList != album else {
                    return
                }
                self?.albumList = album
                self?.embedNavView?.title = album.title
                self?.loadPhotos()
                self?.embedNavView?.reset()
            }
            
            embedAlbumListView?.hideBlock = { [weak self] in
                self?.embedNavView?.reset()
            }
            
            view.addSubview(embedAlbumListView!)
        } else if PhotoConfiguration.default().style == .externalAlbumList {
            externalNavView = PBExternalAlbumListNavView(title: albumList.title)
            
            externalNavView?.backBlock = { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
            
            externalNavView?.cancelBlock = { [weak self] in
                let nav = self?.navigationController as? PBImageNavController
                nav?.cancelBlock?()
                nav?.dismiss(animated: true, completion: nil)
            }
            
            view.addSubview(externalNavView!)
        }
    }
    
    func loadPhotos() {
        let nav = navigationController as! PBImageNavController
        if albumList.models.isEmpty {
            let hud = PBProgressHUD(style: PhotoConfiguration.default().hudStyle)
            hud.show()
            DispatchQueue.global().async {
                self.albumList.refetchPhotos(sortAscending: PhotoConfiguration.default().sortAscending, allowSelectImage: PhotoConfiguration.default().allowSelectImage, allowSelectVideo: PhotoConfiguration.default().allowSelectVideo)
                DispatchQueue.main.async { [self] in
                    self.arrDataSources.removeAll()
                    self.arrDataSources.append(contentsOf: self.albumList.models)
                    markSelected(source: &self.arrDataSources, selected: &nav.arrSelectedModels)
                    hud.hide()
                    self.collectionView.reloadData()
                    self.scrollToBottom()
                }
            }
        } else {
            arrDataSources.removeAll()
            arrDataSources.append(contentsOf: albumList.models)
            markSelected(source: &arrDataSources, selected: &nav.arrSelectedModels)
            collectionView.reloadData()
            scrollToBottom()
        }
    }
    
    // MARK: btn actions
    
    @objc func previewBtnClick() {
        let nav = navigationController as! PBImageNavController
        let vc = PBPhotoPreviewController(photos: nav.arrSelectedModels, index: 0)
        show(vc, sender: nil)
    }
    
    @objc func originalPhotoClick() {
        originalBtn.isSelected = !originalBtn.isSelected
        (navigationController as? PBImageNavController)?.isSelectedOriginal = originalBtn.isSelected
    }
    
    @objc func doneBtnClick() {
        let nav = navigationController as? PBImageNavController
        nav?.selectImageBlock?()
    }
    
    @objc func slideSelectAction(_ pan: UIPanGestureRecognizer) {
        let point = pan.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else {
            return
        }
        let config = PhotoConfiguration.default()
        let nav = navigationController as! PBImageNavController
        
        let cell = collectionView.cellForItem(at: indexPath) as? PBThumbnailPhotoCell
        let asc = config.sortAscending
        
        if pan.state == .began {
            beginPanSelect = (cell != nil)
            
            if beginPanSelect {
                let index = asc ? indexPath.row : indexPath.row - offset
                
                let m = arrDataSources[index]
                panSelectType = m.isSelected ? .cancel : .select
                beginSlideIndexPath = indexPath
                
                if !m.isSelected, nav.arrSelectedModels.count < config.maxSelectCount, canAddModel(m, currentSelectCount: nav.arrSelectedModels.count, sender: self) {
                    if shouldDirectEdit(m) {
                        panSelectType = .none
                        return
                    } else {
                        m.isSelected = true
                        nav.arrSelectedModels.append(m)
                    }
                } else if m.isSelected {
                    m.isSelected = false
                    nav.arrSelectedModels.removeAll { $0 == m }
                }
                
                cell?.btnSelect.isSelected = m.isSelected
                refreshCellIndexAndMaskView()
                resetBottomToolBtnStatus()
                lastSlideIndex = indexPath.row
            }
        } else if pan.state == .changed {
            autoScrollWhenSlideSelect(pan)
            
            if !beginPanSelect || indexPath.row == lastSlideIndex || panSelectType == .none || cell == nil {
                return
            }
            guard let beginIndexPath = beginSlideIndexPath else {
                return
            }
            lastPanUpdateTime = CACurrentMediaTime()
            
            let visiblePaths = collectionView.indexPathsForVisibleItems
            slideCalculateQueue.async {
                self.lastSlideIndex = indexPath.row
                let minIndex = min(indexPath.row, beginIndexPath.row)
                let maxIndex = max(indexPath.row, beginIndexPath.row)
                let minIsBegin = minIndex == beginIndexPath.row
                
                var i = beginIndexPath.row
                while (minIsBegin ? i <= maxIndex : i >= minIndex) {
                    if i != beginIndexPath.row {
                        let p = IndexPath(row: i, section: 0)
                        if !self.arrSlideIndexPaths.contains(p) {
                            self.arrSlideIndexPaths.append(p)
                            let index = asc ? i : i - self.offset
                            let m = self.arrDataSources[index]
                            self.dicOriSelectStatus[p] = m.isSelected
                        }
                    }
                    i += (minIsBegin ? 1 : -1)
                }
                
                var selectedArrHasChange = false
                
                for path in self.arrSlideIndexPaths {
                    if !visiblePaths.contains(path) {
                        continue
                    }
                    let index = asc ? path.row : path.row - self.offset
                    // 是否在最初和现在的间隔区间内
                    let inSection = path.row >= minIndex && path.row <= maxIndex
                    let m = self.arrDataSources[index]
                    
                    if self.panSelectType == .select {
                        if inSection,
                           !m.isSelected,
                           canAddModel(m, currentSelectCount: nav.arrSelectedModels.count, sender: self, showAlert: false) {
                            m.isSelected = true
                        }
                    } else if self.panSelectType == .cancel {
                        if inSection {
                            m.isSelected = false
                        }
                    }
                    
                    if !inSection {
                        // 未在区间内的model还原为初始选择状态
                        m.isSelected = self.dicOriSelectStatus[path] ?? false
                    }
                    if !m.isSelected {
                        if let index = nav.arrSelectedModels.firstIndex(where: { $0 == m }) {
                            nav.arrSelectedModels.remove(at: index)
                            selectedArrHasChange = true
                        }
                    } else {
                        if !nav.arrSelectedModels.contains(where: { $0 == m }) {
                            nav.arrSelectedModels.append(m)
                            selectedArrHasChange = true
                        }
                    }
                    
                    DispatchQueue.main.async {
                        let c = self.collectionView.cellForItem(at: path) as? PBThumbnailPhotoCell
                        c?.btnSelect.isSelected = m.isSelected
                    }
                }
                
                if selectedArrHasChange {
                    DispatchQueue.main.async {
                        self.refreshCellIndexAndMaskView()
                        self.resetBottomToolBtnStatus()
                    }
                }
            }
        } else if pan.state == .ended || pan.state == .cancelled {
            cleanTimer()
            panSelectType = .none
            arrSlideIndexPaths.removeAll()
            dicOriSelectStatus.removeAll()
            resetBottomToolBtnStatus()
        }
    }
    
    func autoScrollWhenSlideSelect(_ pan: UIPanGestureRecognizer) {
        guard PhotoConfiguration.default().autoScrollWhenSlideSelectIsActive else {
            return
        }
        let arrSel = (navigationController as? PBImageNavController)?.arrSelectedModels ?? []
        guard arrSel.count < PhotoConfiguration.default().maxSelectCount else {
            // Stop auto scroll when reach the max select count.
            cleanTimer()
            return
        }
        
        let top = ((embedNavView?.frame.height ?? externalNavView?.frame.height) ?? 44) + 30
        let bottom = bottomView.frame.minY - 30
        
        let point = pan.location(in: view)
        
        var diff: CGFloat = 0
        var direction: AutoScrollDirection = .none
        if point.y < top {
            diff = top - point.y
            direction = .top
        } else if point.y > bottom {
            diff = point.y - bottom
            direction = .bottom
        } else {
            autoScrollInfo = (.none, 0)
            cleanTimer()
            return
        }
        
        guard diff > 0 else { return }
        
        let s = min(diff, 60) / 60 * PhotoConfiguration.default().autoScrollMaxSpeed
        
        autoScrollInfo = (direction, s)
        
        if autoScrollTimer == nil {
            cleanTimer()
            autoScrollTimer = CADisplayLink(target: self, selector: #selector(autoScrollAction))
            autoScrollTimer?.add(to: RunLoop.current, forMode: .common)
        }
    }
    
    func cleanTimer() {
        autoScrollTimer?.remove(from: RunLoop.current, forMode: .common)
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
    
    @objc func autoScrollAction() {
        guard autoScrollInfo.direction != .none else { return }
        let duration = CGFloat(autoScrollTimer?.duration ?? 1 / 60)
        if CACurrentMediaTime() - lastPanUpdateTime > 0.2 {
            // Finger may be not moved in slide selection mode
            slideSelectAction(panGes)
        }
        let distance = autoScrollInfo.speed * duration
        let offset = collectionView.contentOffset
        let inset = collectionView.contentInset
        if autoScrollInfo.direction == .top, offset.y + inset.top > distance {
            collectionView.contentOffset = CGPoint(x: 0, y: offset.y - distance)
        } else if autoScrollInfo.direction == .bottom, offset.y + collectionView.bounds.height + distance - inset.bottom < collectionView.contentSize.height {
            collectionView.contentOffset = CGPoint(x: 0, y: offset.y + distance)
        }
    }
    
    func resetBottomToolBtnStatus() {
        let nav = navigationController as! PBImageNavController
        if nav.arrSelectedModels.count > 0 {
            previewBtn.isEnabled = true
            doneBtn.isEnabled = true
            let doneTitle = "完成" + "(" + String(nav.arrSelectedModels.count) + ")"
            doneBtn.setTitle(doneTitle, for: .normal)
            doneBtn.backgroundColor = .bottomToolViewBtnNormalBgColor
        } else {
            previewBtn.isEnabled = false
            doneBtn.isEnabled = false
            doneBtn.setTitle("完成", for: .normal)
            doneBtn.backgroundColor = .bottomToolViewBtnDisableBgColor
        }
        originalBtn.isSelected = nav.isSelectedOriginal
        refreshDoneBtnFrame()
    }
    
    func refreshDoneBtnFrame() {
        let selCount = (navigationController as? PBImageNavController)?.arrSelectedModels.count ?? 0
        var doneTitle = "完成"
        if selCount > 0 {
            doneTitle += "(" + String(selCount) + ")"
        }
        let doneBtnW = doneTitle.boundingRect(font: PBLayout.bottomToolTitleFont, limitSize: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 30)).width + 20
        doneBtn.frame = CGRect(x: bottomView.bounds.width-doneBtnW-15, y: 7, width: doneBtnW, height: PBLayout.bottomToolBtnH)
    }
    
    func scrollToBottom() {
        guard PhotoConfiguration.default().sortAscending, arrDataSources.count > 0 else {
            return
        }
        let index = arrDataSources.count - 1 + offset
        collectionView.scrollToItem(at: IndexPath(row: index, section: 0), at: .centeredVertically, animated: false)
    }
    
    func showCamera() {
        let config = PhotoConfiguration.default()
        if config.useCustomCamera {
            let camera = PBCustomCamera()
            camera.takeDoneBlock = { [weak self] (image, videoUrl) in
                self?.save(image: image, videoUrl: videoUrl)
            }
            showDetailViewController(camera, sender: nil)
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
                showDetailViewController(picker, sender: nil)
            } else {
                showAlertView("相机不可用", self)
            }
        }
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
                    showAlertView("保存图片失败", self)
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
                    showAlertView("保存视频失败", self)
                }
                hud.hide()
            }
        }
    }
    
    func handleDataArray(newModel: PBPhotoModel) {
        hasTakeANewAsset = true
        albumList.refreshResult()
        
        let nav = navigationController as? PBImageNavController
        let config = PhotoConfiguration.default()
        var insertIndex = 0
        
        if config.sortAscending {
            insertIndex = arrDataSources.count
            arrDataSources.append(newModel)
        } else {
            // 保存拍照的照片或者视频，说明肯定有camera cell
            insertIndex = offset
            arrDataSources.insert(newModel, at: 0)
        }
        
        var canSelect = true
        // If mixed selection is not allowed, and the newModel type is video, it will not be selected.
        if !config.allowMixSelect, newModel.type == .video {
            canSelect = false
        }
        if canSelect, canAddModel(newModel, currentSelectCount: nav?.arrSelectedModels.count ?? 0, sender: self, showAlert: false) {
            if !shouldDirectEdit(newModel) {
                newModel.isSelected = true
                nav?.arrSelectedModels.append(newModel)
            }
        }
        
        let insertIndexPath = IndexPath(row: insertIndex, section: 0)
        collectionView.performBatchUpdates({
            collectionView.insertItems(at: [insertIndexPath])
        }) { (_) in
            self.collectionView.scrollToItem(at: insertIndexPath, at: .centeredVertically, animated: true)
            self.collectionView.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
        }
        
        resetBottomToolBtnStatus()
    }
    
    func showEditImageVC(model: PBPhotoModel) {
        let nav = navigationController as! PBImageNavController
        
        let hud = PBProgressHUD(style: PhotoConfiguration.default().hudStyle)
        hud.show()
        
        hud.show()
        PBPhotoManager.fetchImage(for: model.asset, size: model.previewSize) { [weak self, weak nav] (image, isDegraded) in
            if !isDegraded {
                if let image = image {
                    PBEditImageViewController.showEditImageVC(parentVC: self, image: image, editModel: model.editImageModel) { [weak nav] (ei, editImageModel) in
                        model.isSelected = true
                        model.editImage = ei
                        model.editImageModel = editImageModel
                        nav?.arrSelectedModels.append(model)
                        nav?.selectImageBlock?()
                    }
                } else {
                    showAlertView("图片加载失败", self)
                }
                hud.hide()
            }
        }
    }
    
    func showEditVideoVC(model: PBPhotoModel) {
        let nav = navigationController as! PBImageNavController
        let hud = PBProgressHUD(style: PhotoConfiguration.default().hudStyle)
        
        var requestAvAssetID: PHImageRequestID?
        
        hud.show(timeout: 20)
        hud.timeoutBlock = { [weak self] in
            showAlertView("请求超时", self)
            if let _ = requestAvAssetID {
                PHImageManager.default().cancelImageRequest(requestAvAssetID!)
            }
        }
        
        func inner_showEditVideoVC(_ avAsset: AVAsset) {
            let vc = PBEditVideoViewController(avAsset: avAsset)
            vc.editFinishBlock = { [weak self, weak nav] (url) in
                if let u = url {
                    PBPhotoManager.saveVideoToAlbum(url: u) { [weak self, weak nav] (suc, asset) in
                        if suc, asset != nil {
                            let m = PBPhotoModel(asset: asset!)
                            m.isSelected = true
                            nav?.arrSelectedModels.append(m)
                            nav?.selectImageBlock?()
                        } else {
                            showAlertView("保存视频失败", self)
                        }
                    }
                } else {
                    nav?.arrSelectedModels.append(model)
                    nav?.selectImageBlock?()
                }
            }
            vc.modalPresentationStyle = .fullScreen
            showDetailViewController(vc, sender: nil)
        }
        
        // 提前fetch一下 avasset
        requestAvAssetID = PBPhotoManager.fetchAVAsset(forVideo: model.asset) { [weak self] (avAsset, _) in
            hud.hide()
            if let _ = avAsset {
                inner_showEditVideoVC(avAsset!)
            } else {
                showAlertView("localLanguageTextValue(.timeout)", self)
            }
        }
    }
    
}

// MARK: CollectionView Delegate & DataSource
extension PBThumbnailViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return PBLayout.thumbCollectionViewItemSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return PBLayout.thumbCollectionViewLineSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let defaultCount = CGFloat(PhotoConfiguration.default().columnCount)
        var columnCount: CGFloat = deviceIsiPad() ? (defaultCount+2) : defaultCount
        if isLandscape() {
            columnCount += 2
        }
        let totalW = collectionView.bounds.width - (columnCount - 1) * PBLayout.thumbCollectionViewItemSpacing
        let singleW = totalW / columnCount
        return CGSize(width: singleW, height: singleW)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        if #available(iOS 14.0, *), PBPhotoManager.authorizationStatus(for: .readWrite) == .limited, PhotoConfiguration.default().showEnterSettingFooter, albumList.isCameraRoll {
            return CGSize(width: collectionView.bounds.width, height: 50)
        } else {
            return .zero
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: NSStringFromClass(PBThumbnailColViewFooter.classForCoder()), for: indexPath) as! PBThumbnailColViewFooter
        
        if #available(iOS 14, *) {
            view.selectMoreBlock = {
                guard let url = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        }
        
        return view
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return arrDataSources.count + offset
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let config = PhotoConfiguration.default()
        if showCameraCell && ((config.sortAscending && indexPath.row == arrDataSources.count) || (!config.sortAscending && indexPath.row == 0)) {
            // camera cell
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PBCameraCell.pb_identifier(), for: indexPath) as! PBCameraCell
            
            if config.showCaptureImageOnTakePhotoBtn {
                cell.startCapture()
            }
            
            return cell
        }
        
        if #available(iOS 14, *) {
            if showAddPhotoCell && ((config.sortAscending && indexPath.row == arrDataSources.count - 1 + offset) || (!config.sortAscending && indexPath.row == offset - 1)) {
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PBAddPhotoCell.pb_identifier(), for: indexPath) as? PBAddPhotoCell else {
                    return UICollectionViewCell()
                }
                return cell
            }
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PBThumbnailPhotoCell.pb_identifier(), for: indexPath) as! PBThumbnailPhotoCell
        
        let model: PBPhotoModel
        
        if !config.sortAscending {
            model = arrDataSources[indexPath.row - offset]
        } else {
            model = arrDataSources[indexPath.row]
        }
        
        let nav = navigationController as? PBImageNavController
        cell.selectedBlock = { [weak self, weak nav, weak cell] (isSelected) in
            if !isSelected {
                let currentSelectCount = nav?.arrSelectedModels.count ?? 0
                guard canAddModel(model, currentSelectCount: currentSelectCount, sender: self) else {
                    return
                }
                if self?.shouldDirectEdit(model) == false {
                    model.isSelected = true
                    nav?.arrSelectedModels.append(model)
                    cell?.btnSelect.isSelected = true
                    self?.refreshCellIndexAndMaskView()
                }
            } else {
                cell?.btnSelect.isSelected = false
                model.isSelected = false
                nav?.arrSelectedModels.removeAll { $0 == model }
                self?.refreshCellIndexAndMaskView()
            }
            self?.resetBottomToolBtnStatus()
        }
        
        cell.indexLabel.isHidden = true
        if PhotoConfiguration.default().showSelectedIndex {
            for (index, selM) in (nav?.arrSelectedModels ?? []).enumerated() {
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
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let c = cell as? PBThumbnailPhotoCell else {
            return
        }
        var index = indexPath.row
        if !PhotoConfiguration.default().sortAscending {
            index -= offset
        }
        let model = arrDataSources[index]
        setCellMaskView(c, isSelected: model.isSelected, model: model)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let c = collectionView.cellForItem(at: indexPath)
        if c is PBCameraCell {
            showCamera()
            return
        }
        if #available(iOS 14, *) {
            if c is PBAddPhotoCell {
                PBPhotoManager.presentLimitedLibraryPicker(from: self)
                return
            }
        }
        
        guard let cell = c as? PBThumbnailPhotoCell else {
            return
        }
        
        if !PhotoConfiguration.default().allowPreviewPhotos {
            cell.btnSelectClick()
            return
        }
        
        if !cell.enableSelect, PhotoConfiguration.default().showInvalidMask {
            return
        }
        let config = PhotoConfiguration.default()
        
        var index = indexPath.row
        if !config.sortAscending {
            index -= offset
        }
        let m = arrDataSources[index]
        if shouldDirectEdit(m) {
            return
        }
        
        let vc = PBPhotoPreviewController(photos: arrDataSources, index: index)
        show(vc, sender: nil)
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
        let nav = navigationController as? PBImageNavController
        let arrSelectedModels = nav?.arrSelectedModels ?? []
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
    
    func refreshCellIndexAndMaskView() {
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
            var row = indexPath.row
            if !PhotoConfiguration.default().sortAscending {
                row -= offset
            }
            let m = arrDataSources[row]
            
            let arrSel = (navigationController as? PBImageNavController)?.arrSelectedModels ?? []
            var show = false
            var idx = 0
            var isSelected = false
            for (index, selM) in arrSel.enumerated() {
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
        let arrSel = (navigationController as? PBImageNavController)?.arrSelectedModels ?? []
        let config = PhotoConfiguration.default()
        
        if isSelected {
            cell.coverView.backgroundColor = .selectedMaskColor
            cell.coverView.isHidden = !config.showSelectedMask
            if config.showSelectedBorder {
                cell.layer.borderWidth = 4
            }
        } else {
            let selCount = arrSel.count
            if selCount < config.maxSelectCount {
                if config.allowMixSelect {
                    let videoCount = arrSel.filter { $0.type == .video }.count
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
    
}


extension PBThumbnailViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) {
            let image = info[.originalImage] as? UIImage
            let url = info[.mediaURL] as? URL
            self.save(image: image, videoUrl: url)
        }
    }
    
}


extension PBThumbnailViewController: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let changes = changeInstance.changeDetails(for: albumList.result)
            else { return }
        DispatchQueue.main.sync {
            // 变化后再次显示相册列表需要刷新
            hasTakeANewAsset = true
            albumList.result = changes.fetchResultAfterChanges
            let nav = (navigationController as! PBImageNavController)
            if changes.hasIncrementalChanges {
                for sm in nav.arrSelectedModels {
                    let isDelete = changeInstance.changeDetails(for: sm.asset)?.objectWasDeleted ?? false
                    if isDelete {
                        nav.arrSelectedModels.removeAll { $0 == sm }
                    }
                }
                if (!changes.removedObjects.isEmpty || !changes.insertedObjects.isEmpty) {
                    albumList.models.removeAll()
                }
                
                loadPhotos()
            } else {
                for sm in nav.arrSelectedModels {
                    let isDelete = changeInstance.changeDetails(for: sm.asset)?.objectWasDeleted ?? false
                    if isDelete {
                        nav.arrSelectedModels.removeAll { $0 == sm }
                    }
                }
                albumList.models.removeAll()
                loadPhotos()
            }
            resetBottomToolBtnStatus()
        }
    }
    
}


// MARK: embed album list nav view
class PBEmbedAlbumListNavView: UIView {
    
    static let titleViewH: CGFloat = 32
    
    static let arrowH: CGFloat = 20
    
    var title: String {
        didSet {
            albumTitleLabel.text = title
            refreshTitleViewFrame()
        }
    }
    
    var navBlurView: UIVisualEffectView?
    
    var titleBgControl: UIControl!
    
    var albumTitleLabel: UILabel!
    
    var arrow: UIImageView!
    
    var cancelBtn: UIButton!
    
    var selectAlbumBlock: ( () -> Void )?
    
    var cancelBlock: ( () -> Void )?
    
    init(title: String) {
        self.title = title
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var insets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        if #available(iOS 11.0, *) {
            insets = safeAreaInsets
        }
        
        refreshTitleViewFrame()
        let cancelBtnW: CGFloat = 40.0
        cancelBtn.frame = CGRect(x: insets.left + 10, y: insets.top, width: cancelBtnW, height: 44)
    }
    
    func refreshTitleViewFrame() {
        var insets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        if #available(iOS 11.0, *) {
            insets = safeAreaInsets
        }
        
        navBlurView?.frame = bounds
        
        let albumTitleW = min(bounds.width / 2, title.boundingRect(font: PBLayout.navTitleFont, limitSize: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 44)).width)
        let titleBgControlW = albumTitleW + PBEmbedAlbumListNavView.arrowH + 20
        
        UIView.animate(withDuration: 0.25) {
            self.titleBgControl.frame = CGRect(x: (self.frame.width-titleBgControlW)/2, y: insets.top+(44-PBEmbedAlbumListNavView.titleViewH)/2, width: titleBgControlW, height: PBEmbedAlbumListNavView.titleViewH)
            self.albumTitleLabel.frame = CGRect(x: 10, y: 0, width: albumTitleW, height: PBEmbedAlbumListNavView.titleViewH)
            self.arrow.frame = CGRect(x: self.albumTitleLabel.self.frame.maxX+5, y: (PBEmbedAlbumListNavView.titleViewH-PBEmbedAlbumListNavView.arrowH)/2.0, width: PBEmbedAlbumListNavView.arrowH, height: PBEmbedAlbumListNavView.arrowH)
        }
    }
    
    func setupUI() {
        backgroundColor = .navBarColor
        
        if let effect = PhotoConfiguration.default().navViewBlurEffect {
            navBlurView = UIVisualEffectView(effect: effect)
            addSubview(navBlurView!)
        }
        
        titleBgControl = UIControl()
        titleBgControl.backgroundColor = .navEmbedTitleViewBgColor
        titleBgControl.layer.cornerRadius = PBEmbedAlbumListNavView.titleViewH / 2
        titleBgControl.layer.masksToBounds = true
        titleBgControl.addTarget(self, action: #selector(titleBgControlClick), for: .touchUpInside)
        addSubview(titleBgControl)
        
        albumTitleLabel = UILabel()
        albumTitleLabel.textColor = .navTitleColor
        albumTitleLabel.font = PBLayout.navTitleFont
        albumTitleLabel.text = title
        albumTitleLabel.textAlignment = .center
        titleBgControl.addSubview(albumTitleLabel)
        
        arrow = UIImageView(image: getImage("pb_downArrow"))
        arrow.clipsToBounds = true
        arrow.contentMode = .scaleAspectFill
        titleBgControl.addSubview(arrow)
        
        cancelBtn = UIButton(type: .custom)
        cancelBtn.titleLabel?.font = PBLayout.navTitleFont
        cancelBtn.setTitle("取消", for: .normal)
        cancelBtn.titleLabel?.textAlignment = .center
        cancelBtn.setTitleColor(.navTitleColor, for: .normal)
        cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        addSubview(cancelBtn)
    }
    
    @objc func titleBgControlClick() {
        selectAlbumBlock?()
        if arrow.transform == .identity {
            UIView.animate(withDuration: 0.25) {
                self.arrow.transform = CGAffineTransform(rotationAngle: .pi)
            }
        } else {
            UIView.animate(withDuration: 0.25) {
                self.arrow.transform = .identity
            }
        }
    }
    
    @objc func cancelBtnClick() {
        cancelBlock?()
    }
    
    func reset() {
        UIView.animate(withDuration: 0.25) {
            self.arrow.transform = .identity
        }
    }
    
}


// MARK: external album list nav view
class PBExternalAlbumListNavView: UIView {
    
    let title: String
    
    var navBlurView: UIVisualEffectView?
    
    var backBtn: UIButton!
    
    var albumTitleLabel: UILabel!
    
    var cancelBtn: UIButton!
    
    var backBlock: ( () -> Void )?
    
    var cancelBlock: ( () -> Void )?
    
    init(title: String) {
        self.title = title
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var insets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        if #available(iOS 11.0, *) {
            insets = safeAreaInsets
        }
        
        navBlurView?.frame = bounds
        
        backBtn.frame = CGRect(x: insets.left, y: insets.top, width: 60, height: 44)
        let albumTitleW = min(bounds.width / 2, title.boundingRect(font: PBLayout.navTitleFont, limitSize: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 44)).width)
        albumTitleLabel.frame = CGRect(x: (frame.width-albumTitleW)/2, y: insets.top, width: albumTitleW, height: 44)
        let cancelBtnW: CGFloat = 60.0
        cancelBtn.frame = CGRect(x: frame.width-insets.right-cancelBtnW, y: insets.top, width: cancelBtnW, height: 44)
    }
    
    func setupUI() {
        backgroundColor = .navBarColor
        
        if let effect = PhotoConfiguration.default().navViewBlurEffect {
            navBlurView = UIVisualEffectView(effect: effect)
            addSubview(navBlurView!)
        }
        
        backBtn = UIButton(type: .custom)
        backBtn.setImage(getImage("pb_navBack"), for: .normal)
        backBtn.imageEdgeInsets = UIEdgeInsets(top: 0, left: -25, bottom: 0, right: 0)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        addSubview(backBtn)
        
        albumTitleLabel = UILabel()
        albumTitleLabel.textColor = .navTitleColor
        albumTitleLabel.font = PBLayout.navTitleFont
        albumTitleLabel.text = title
        albumTitleLabel.textAlignment = .center
        addSubview(albumTitleLabel)
        
        cancelBtn = UIButton(type: .custom)
        cancelBtn.titleLabel?.font = PBLayout.navTitleFont
        cancelBtn.setTitle("取消", for: .normal)
        cancelBtn.titleLabel?.textAlignment = .center
        cancelBtn.setTitleColor(.navTitleColor, for: .normal)
        cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        addSubview(cancelBtn)
    }
    
    @objc func backBtnClick() {
        backBlock?()
    }
    
    @objc func cancelBtnClick() {
        cancelBlock?()
    }
    
}


class PBThumbnailColViewFooter: UICollectionReusableView {
    
    var selectPhotoLabel: UILabel!
    
    var selectMoreBlock: ( () -> Void )?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        selectPhotoLabel = UILabel(frame: CGRect(x: 20, y: 0, width: bounds.width - 40, height: bounds.height))
        selectPhotoLabel.font = UIFont.systemFont(ofSize: 14)
        selectPhotoLabel.numberOfLines = 2
        selectPhotoLabel.textAlignment = .center
        selectPhotoLabel.textColor = .selectMorePhotoWhenAuthIsLismitedTitleColor
        selectPhotoLabel.text = "无法访问所有照片，前往设置"
        addSubview(selectPhotoLabel)
        
        let control = UIControl(frame: bounds)
        control.addTarget(self, action: #selector(selectMorePhoto), for: .touchUpInside)
        addSubview(control)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func selectMorePhoto() {
        selectMoreBlock?()
    }
    
}
