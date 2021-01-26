//
//  PBPhotoPreviewController.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit
import Photos
import PhotoLib
class PBPhotoPreviewController: UIViewController {

    static let colItemSpacing: CGFloat = 40
    
    static let selPhotoPreviewH: CGFloat = 100
    
    static let previewVCScrollNotification = Notification.Name("previewVCScrollNotification")
    
    let arrDataSources: [PBPhotoModel]
    
    let showBottomViewAndSelectBtn: Bool
    
    var currentIndex: Int
    
    var indexBeforOrientationChanged: Int
    
    var collectionView: UICollectionView!
    
    var navView: UIView!
    
    var navBlurView: UIVisualEffectView?
    
    var backBtn: UIButton!
    
    var selectBtn: UIButton!
    
    var indexLabel: UILabel!
    
    var bottomView: UIView!
    
    var bottomBlurView: UIVisualEffectView?
    
    var editBtn: UIButton!
    
    var originalBtn: UIButton!
    
    var doneBtn: UIButton!
    
    var selPhotoPreview: PBPhotoPreviewSelectedView?
    
    var isFirstLayout = true
    
    var isFirstAppear = true
    
    var hideNavView = false
    
    var popInteractiveTransition: PBPhotoPreviewPopInteractiveTransition?
    
    /// 是否在点击确定时候，当未选择任何照片时候，自动选择当前index的照片
    var autoSelectCurrentIfNotSelectAnyone = true
    
    /// 界面消失时，通知上个界面刷新（针对预览视图）
    var backBlock: ( () -> Void )?
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return PhotoConfiguration.default().statusBarStyle
    }
    
    init(photos: [PBPhotoModel], index: Int, showBottomViewAndSelectBtn: Bool = true) {
        arrDataSources = photos
        self.showBottomViewAndSelectBtn = showBottomViewAndSelectBtn
        currentIndex = index
        indexBeforOrientationChanged = index
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        addPopInteractiveTransition()
        resetSubViewStatus(animateIndexLabel: false)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        indexBeforOrientationChanged = currentIndex
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.delegate = self
        
        guard isFirstAppear else { return }
        isFirstAppear = false
        
        reloadCurrentCell()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        var insets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        if #available(iOS 11.0, *) {
            insets = view.safeAreaInsets
        }
        
        collectionView.frame = CGRect(x: -PBPhotoPreviewController.colItemSpacing / 2, y: 0, width: view.frame.width + PBPhotoPreviewController.colItemSpacing, height: view.frame.height)
        collectionView.setContentOffset(CGPoint(x: (view.frame.width + PBPhotoPreviewController.colItemSpacing) * CGFloat(indexBeforOrientationChanged), y: 0), animated: false)
        
        let navH = insets.top + 44
        navView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: navH)
        navBlurView?.frame = navView.bounds
        
        backBtn.frame = CGRect(x: insets.left, y: insets.top, width: 60, height: 44)
        selectBtn.frame = CGRect(x: view.frame.width - 40 - insets.right, y: insets.top + (44 - 25) / 2, width: 25, height: 25)
        indexLabel.frame = selectBtn.frame
        
        refreshBottomViewFrame()
        
        guard isFirstLayout else { return }
        isFirstLayout = false
        if currentIndex > 0 {
            collectionView.contentOffset = CGPoint(x: (view.bounds.width + PBPhotoPreviewController.colItemSpacing) * CGFloat(currentIndex), y: 0)
        }
    }
    
    func reloadCurrentCell() {
        guard let cell = collectionView.cellForItem(at: IndexPath(row: currentIndex, section: 0)) else {
            return
        }
        if let cell = cell as? PBGifPreviewCell {
            cell.loadGifWhenCellDisplaying()
        } else if let cell = cell as? PBLivePhotoPewviewCell {
            cell.loadLivePhotoData()
        }
    }
    
    func refreshBottomViewFrame() {
        var insets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        if #available(iOS 11.0, *) {
            insets = view.safeAreaInsets
        }
        var bottomViewH = PBLayout.bottomToolViewH
        var showSelPhotoPreview = false
        if PhotoConfiguration.default().showSelectedPhotoPreview {
            let nav = navigationController as! PBImageNavController
            if !nav.arrSelectedModels.isEmpty {
                showSelPhotoPreview = true
                bottomViewH += PBPhotoPreviewController.selPhotoPreviewH
                selPhotoPreview?.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: PBPhotoPreviewController.selPhotoPreviewH)
            }
        }
        let btnH = PBLayout.bottomToolBtnH
        
        bottomView.frame = CGRect(x: 0, y: view.frame.height-insets.bottom-bottomViewH, width: view.frame.width, height: bottomViewH+insets.bottom)
        bottomBlurView?.frame = bottomView.bounds
        
        let btnY: CGFloat = showSelPhotoPreview ? PBPhotoPreviewController.selPhotoPreviewH + 7 : 7
        
//        let editTitle = "编辑"
        let editBtnW: CGFloat = 40.0
        editBtn.frame = CGRect(x: 15, y: btnY, width: editBtnW, height: btnH)
        
//        let originalTitle = "原图"
        let w: CGFloat = 70.0
        originalBtn.frame = CGRect(x: (bottomView.bounds.width-w)/2-5, y: btnY, width: w, height: btnH)
        
        let selCount = (navigationController as? PBImageNavController)?.arrSelectedModels.count ?? 0
        var doneTitle = "完成"
        if selCount > 0 {
            doneTitle += "(" + String(selCount) + ")"
        }
        let doneBtnW = doneTitle.boundingRect(font: PBLayout.bottomToolTitleFont, limitSize: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 30)).width + 20
        doneBtn.frame = CGRect(x: bottomView.bounds.width-doneBtnW-15, y: btnY, width: doneBtnW, height: btnH)
    }
    
    func setupUI() {
        view.backgroundColor = .black
        if #available(iOS 11.0, *) {
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }
        
        let config = PhotoConfiguration.default()
        // nav view
        navView = UIView()
        navView.backgroundColor = .navBarColor
        view.addSubview(navView)
        
        if let effect = config.navViewBlurEffect {
            navBlurView = UIVisualEffectView(effect: effect)
            navView.addSubview(navBlurView!)
        }
        
        backBtn = UIButton(type: .custom)
        backBtn.setImage(getImage("pb_navBack"), for: .normal)
        backBtn.imageEdgeInsets = UIEdgeInsets(top: 0, left: -25, bottom: 0, right: 0)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        navView.addSubview(backBtn)
        
        selectBtn = UIButton(type: .custom)
        selectBtn.setImage(getImage("pb_btn_circle"), for: .normal)
        selectBtn.setImage(getImage("pb_btn_selected"), for: .selected)
        selectBtn.enlargeValidTouchArea(inset: 10)
        selectBtn.addTarget(self, action: #selector(selectBtnClick), for: .touchUpInside)
        navView.addSubview(selectBtn)
        
        indexLabel = UILabel()
        indexLabel.backgroundColor = .indexLabelBgColor
        indexLabel.font = UIFont.systemFont(ofSize: 14)
        indexLabel.textColor = .white
        indexLabel.textAlignment = .center
        indexLabel.layer.cornerRadius = 25.0 / 2
        indexLabel.layer.masksToBounds = true
        indexLabel.isHidden = true
        navView.addSubview(indexLabel)
        
        // collection view
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        view.addSubview(collectionView)
        
        PBPhotoPreviewCell.pb_register(collectionView)
        PBGifPreviewCell.pb_register(collectionView)
        PBLivePhotoPewviewCell.pb_register(collectionView)
        PBVideoPreviewCell.pb_register(collectionView)
        
        // bottom view
        bottomView = UIView()
        bottomView.backgroundColor = .bottomToolViewBgColor
        view.addSubview(bottomView)
        
        if let effect = config.bottomToolViewBlurEffect {
            bottomBlurView = UIVisualEffectView(effect: effect)
            bottomView.addSubview(bottomBlurView!)
        }
        
        if config.showSelectedPhotoPreview {
            let nav = navigationController as! PBImageNavController
            selPhotoPreview = PBPhotoPreviewSelectedView(selModels: nav.arrSelectedModels, currentShowModel: arrDataSources[currentIndex])
            selPhotoPreview?.selectBlock = { [weak self] (model) in
                self?.scrollToSelPreviewCell(model)
            }
            selPhotoPreview?.endSortBlock = { [weak self] (models) in
                self?.refreshCurrentCellIndex(models)
            }
            bottomView.addSubview(selPhotoPreview!)
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
        
        editBtn = createBtn("编辑", #selector(editBtnClick))
        editBtn.isHidden = (!config.allowEditImage && !config.allowEditVideo)
        bottomView.addSubview(editBtn)
        
        originalBtn = createBtn("原图", #selector(originalPhotoClick))
        originalBtn.setImage(getImage("pb_btn_original_circle"), for: .normal)
        originalBtn.setImage(getImage("pb_btn_original_selected"), for: .selected)
        originalBtn.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        originalBtn.isHidden = !(config.allowSelectOriginal && config.allowSelectImage)
        originalBtn.isSelected = (navigationController as! PBImageNavController).isSelectedOriginal
        bottomView.addSubview(originalBtn)
        
        doneBtn = createBtn("完成", #selector(doneBtnClick))
        doneBtn.backgroundColor = .bottomToolViewBtnNormalBgColor
        doneBtn.layer.masksToBounds = true
        doneBtn.layer.cornerRadius = PBLayout.bottomToolBtnCornerRadius
        bottomView.addSubview(doneBtn)
        
        view.bringSubviewToFront(navView)
    }
    
    func addPopInteractiveTransition() {
        guard (navigationController?.viewControllers.count ?? 0 ) > 1 else {
            // 仅有当前vc一个时候，说明不是从相册进入，不添加交互动画
            return
        }
        popInteractiveTransition = PBPhotoPreviewPopInteractiveTransition(viewController: self)
        popInteractiveTransition?.shouldStartTransition = { [weak self] (point) -> Bool in
            guard let `self` = self else { return false }
            if !self.hideNavView && (self.navView.frame.contains(point) || self.bottomView.frame.contains(point)) {
                return false
            }
            return true
        }
        popInteractiveTransition?.startTransition = { [weak self] in
            guard let `self` = self else { return }
            
            self.navView.alpha = 0
            self.bottomView.alpha = 0
            
            guard let cell = self.collectionView.cellForItem(at: IndexPath(row: self.currentIndex, section: 0)) else {
                return
            }
            if cell is PBVideoPreviewCell {
                (cell as! PBVideoPreviewCell).pauseWhileTransition()
            } else if cell is PBLivePhotoPewviewCell {
                (cell as! PBLivePhotoPewviewCell).livePhotoView.stopPlayback()
            } else if cell is PBGifPreviewCell {
                (cell as! PBGifPreviewCell).pauseGif()
            }
        }
        popInteractiveTransition?.cancelTransition = { [weak self] in
            guard let `self` = self else { return }
            
            self.hideNavView = false
            self.navView.isHidden = false
            self.bottomView.isHidden = false
            UIView.animate(withDuration: 0.5) {
                self.navView.alpha = 1
                self.bottomView.alpha = 1
            }
            
            guard let cell = self.collectionView.cellForItem(at: IndexPath(row: self.currentIndex, section: 0)) else {
                return
            }
            if cell is PBGifPreviewCell {
                (cell as! PBGifPreviewCell).resumeGif()
            }
        }
    }
    
    func resetSubViewStatus(animateIndexLabel: Bool) {
        let nav = navigationController as! PBImageNavController
        let config = PhotoConfiguration.default()
        let currentModel = arrDataSources[currentIndex]
        
        if (!config.allowMixSelect && currentModel.type == .video) || (!config.showSelectBtnWhenSingleSelect && config.maxSelectCount == 1) {
            selectBtn.isHidden = true
        } else {
            selectBtn.isHidden = false
        }
        selectBtn.isSelected = arrDataSources[currentIndex].isSelected
        resetIndexLabelStatus(animate: animateIndexLabel)
        
        guard showBottomViewAndSelectBtn else {
            selectBtn.isHidden = true
            bottomView.isHidden = true
            return
        }
        let selCount = nav.arrSelectedModels.count
        var doneTitle = "完成"
        if selCount > 0 {
            doneTitle += "(" + String(selCount) + ")"
        }
        doneBtn.setTitle(doneTitle, for: .normal)
        
        selPhotoPreview?.isHidden = selCount == 0
        refreshBottomViewFrame()
        
        var hideEditBtn = true
        if selCount < config.maxSelectCount || nav.arrSelectedModels.contains(where: { $0 == currentModel }) {
            if config.allowEditImage && (currentModel.type == .image || (currentModel.type == .gif && !config.allowSelectGif) || (currentModel.type == .livePhoto && !config.allowSelectLivePhoto)) {
                hideEditBtn = false
            }
            if config.allowEditVideo && currentModel.type == .video && (selCount == 0 || (selCount == 1 && nav.arrSelectedModels.first == currentModel)) {
                hideEditBtn = false
            }
        }
        editBtn.isHidden = hideEditBtn
        
        if PhotoConfiguration.default().allowSelectOriginal && PhotoConfiguration.default().allowSelectImage {
            originalBtn.isHidden = !((currentModel.type == .image) || (currentModel.type == .livePhoto && !config.allowSelectLivePhoto) || (currentModel.type == .gif && !config.allowSelectGif))
        }
    }
    
    func resetIndexLabelStatus(animate: Bool) {
        guard PhotoConfiguration.default().showSelectedIndex else {
            indexLabel.isHidden = true
            return
        }
        let nav = navigationController as! PBImageNavController
        if let index = nav.arrSelectedModels.firstIndex(where: { $0 == arrDataSources[currentIndex] }) {
            indexLabel.isHidden = false
            indexLabel.text = String(index + 1)
        } else {
            indexLabel.isHidden = true
        }
        if animate {
            indexLabel.layer.add(getSpringAnimation(), forKey: nil)
        }
    }
    
    // MARK: btn actions
    
    @objc func backBtnClick() {
        backBlock?()
        let vc = navigationController?.popViewController(animated: true)
        if vc == nil {
            navigationController?.dismiss(animated: true, completion: nil)
        }
    }
    
    @objc func selectBtnClick() {
        let nav = navigationController as! PBImageNavController
        let currentModel = arrDataSources[currentIndex]
        
        if currentModel.isSelected {
            currentModel.isSelected = false
            nav.arrSelectedModels.removeAll { $0 == currentModel }
            selPhotoPreview?.removeSelModel(model: currentModel)
        } else {
            selectBtn.layer.add(getSpringAnimation(), forKey: nil)
            if !canAddModel(currentModel, currentSelectCount: nav.arrSelectedModels.count, sender: self) {
                return
            }
            currentModel.isSelected = true
            nav.arrSelectedModels.append(currentModel)
            selPhotoPreview?.addSelModel(model: currentModel)
        }
        resetSubViewStatus(animateIndexLabel: true)
    }
    
    @objc func editBtnClick() {
        let config = PhotoConfiguration.default()
        let model = arrDataSources[currentIndex]
        let hud = PBProgressHUD(style: config.hudStyle)
        
        if model.type == .image || (!config.allowSelectGif && model.type == .gif) || (!config.allowSelectLivePhoto && model.type == .livePhoto) {
            hud.show()
            PBPhotoManager.fetchImage(for: model.asset, size: model.previewSize) { [weak self] (image, isDegraded) in
                if !isDegraded {
                    if let image = image {
                        self?.showEditImageVC(image: image)
                    } else {
                        showAlertView("图片加载失败", self)
                    }
                    hud.hide()
                }
            }
        } else if model.type == .video || config.allowEditVideo {
            var requestAvAssetID: PHImageRequestID?
            hud.show(timeout: 20)
            hud.timeoutBlock = { [weak self] in
                showAlertView("请求超时", self)
                if let _ = requestAvAssetID {
                    PHImageManager.default().cancelImageRequest(requestAvAssetID!)
                }
            }
            // fetch avasset
            requestAvAssetID = PBPhotoManager.fetchAVAsset(forVideo: model.asset) { [weak self] (avAsset, _) in
                hud.hide()
                if let av = avAsset {
                    self?.showEditVideoVC(model: model, avAsset: av)
                } else {
                    showAlertView("请求超时", self)
                }
            }
        }
    }
    
    @objc func originalPhotoClick() {
        originalBtn.isSelected = !originalBtn.isSelected
        let nav = (navigationController as? PBImageNavController)
        nav?.isSelectedOriginal = originalBtn.isSelected
        if nav?.arrSelectedModels.count == 0 {
            selectBtnClick()
        }
    }
    
    @objc func doneBtnClick() {
        let nav = navigationController as! PBImageNavController
        let currentModel = arrDataSources[currentIndex]
        
        if autoSelectCurrentIfNotSelectAnyone {
            if nav.arrSelectedModels.isEmpty, canAddModel(currentModel, currentSelectCount: nav.arrSelectedModels.count, sender: self) {
                nav.arrSelectedModels.append(currentModel)
            }
            
            if !nav.arrSelectedModels.isEmpty {
                nav.selectImageBlock?()
            }
        } else {
            nav.selectImageBlock?()
        }
    }
    
    func scrollToSelPreviewCell(_ model: PBPhotoModel) {
        guard let index = arrDataSources.lastIndex(of: model) else {
            return
        }
        collectionView.performBatchUpdates({
            collectionView.scrollToItem(at: IndexPath(row: index, section: 0), at: .centeredHorizontally, animated: false)
        }) { (_) in
            self.indexBeforOrientationChanged = self.currentIndex
            self.reloadCurrentCell()
        }
    }
    
    func refreshCurrentCellIndex(_ models: [PBPhotoModel]) {
        let nav = navigationController as? PBImageNavController
        nav?.arrSelectedModels.removeAll()
        nav?.arrSelectedModels.append(contentsOf: models)
        guard PhotoConfiguration.default().showSelectedIndex else {
            return
        }
        resetIndexLabelStatus(animate: false)
    }
    
    func tapPreviewCell() {
        hideNavView = !hideNavView
        let currentCell = collectionView.cellForItem(at: IndexPath(row: currentIndex, section: 0))
        if let cell = currentCell as? PBVideoPreviewCell {
            if cell.isPlaying {
                hideNavView = true
            }
        }
        navView.isHidden = hideNavView
        bottomView.isHidden = showBottomViewAndSelectBtn ? hideNavView : true
    }
    
    func showEditImageVC(image: UIImage) {
        let model = arrDataSources[currentIndex]
        let nav = navigationController as! PBImageNavController
        PBEditImageViewController.showEditImageVC(parentVC: self, image: image, editModel: model.editImageModel) { [weak self, weak nav] (ei, editImageModel) in
            guard let `self` = self else { return }
            model.editImage = ei
            model.editImageModel = editImageModel
            if nav?.arrSelectedModels.contains(where: { $0 == model }) == false {
                model.isSelected = true
                nav?.arrSelectedModels.append(model)
                self.resetSubViewStatus(animateIndexLabel: false)
                self.selPhotoPreview?.addSelModel(model: model)
            } else {
                self.selPhotoPreview?.refreshCell(for: model)
            }
            self.collectionView.reloadItems(at: [IndexPath(row: self.currentIndex, section: 0)])
        }
    }
    
    func showEditVideoVC(model: PBPhotoModel, avAsset: AVAsset) {
        let nav = navigationController as! PBImageNavController
        let vc = PBEditVideoViewController(avAsset: avAsset)
        vc.modalPresentationStyle = .fullScreen
        
        vc.editFinishBlock = { [weak self, weak nav] (url) in
            if let u = url {
                PBPhotoManager.saveVideoToAlbum(url: u) { [weak self, weak nav] (suc, asset) in
                    if suc, asset != nil {
                        let m = PBPhotoModel(asset: asset!)
                        nav?.arrSelectedModels.removeAll()
                        nav?.arrSelectedModels.append(m)
                        nav?.selectImageBlock?()
                    } else {
                        showAlertView("视频保存失败", self)
                    }
                }
            } else {
                nav?.arrSelectedModels.removeAll()
                nav?.arrSelectedModels.append(model)
                nav?.selectImageBlock?()
            }
        }
        
        present(vc, animated: false, completion: nil)
    }
    
}


extension PBPhotoPreviewController: UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if operation == .push {
            return nil
        }
        return popInteractiveTransition?.interactive == true ? PBPhotoPreviewAnimatedTransition() : nil
    }
    
    func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return popInteractiveTransition?.interactive == true ? popInteractiveTransition : nil
    }
    
}


// scroll view delegate
extension PBPhotoPreviewController {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == collectionView else {
            return
        }
        NotificationCenter.default.post(name: PBPhotoPreviewController.previewVCScrollNotification, object: nil)
        let offset = scrollView.contentOffset
        var page = Int(round(offset.x / (view.bounds.width + PBPhotoPreviewController.colItemSpacing)))
        page = max(0, min(page, arrDataSources.count-1))
        if page == currentIndex {
            return
        }
        currentIndex = page
        resetSubViewStatus(animateIndexLabel: false)
        selPhotoPreview?.currentShowModelChanged(model: arrDataSources[currentIndex])
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        indexBeforOrientationChanged = currentIndex
        let cell = collectionView.cellForItem(at: IndexPath(row: currentIndex, section: 0))
        if let cell = cell as? PBGifPreviewCell {
            cell.loadGifWhenCellDisplaying()
        } else if let cell = cell as? PBLivePhotoPewviewCell {
            cell.loadLivePhotoData()
        }
    }
    
}


extension PBPhotoPreviewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return PBPhotoPreviewController.colItemSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return PBPhotoPreviewController.colItemSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: PBPhotoPreviewController.colItemSpacing / 2, bottom: 0, right: PBPhotoPreviewController.colItemSpacing / 2)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: view.bounds.width, height: view.bounds.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return arrDataSources.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let config = PhotoConfiguration.default()
        let model = arrDataSources[indexPath.row]
        
        let baseCell: PBPreviewBaseCell
        
        if config.allowSelectGif, model.type == .gif {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PBGifPreviewCell.pb_identifier(), for: indexPath) as! PBGifPreviewCell
            
            cell.singleTapBlock = { [weak self] in
                self?.tapPreviewCell()
            }
            
            cell.model = model
            
            baseCell = cell
        } else if config.allowSelectLivePhoto, model.type == .livePhoto {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PBLivePhotoPewviewCell.pb_identifier(), for: indexPath) as! PBLivePhotoPewviewCell
            
            cell.model = model
            
            baseCell = cell
        } else if config.allowSelectVideo, model.type == .video {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PBVideoPreviewCell.pb_identifier(), for: indexPath) as! PBVideoPreviewCell
            
            cell.model = model
            
            baseCell = cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PBPhotoPreviewCell.pb_identifier(), for: indexPath) as! PBPhotoPreviewCell

            cell.singleTapBlock = { [weak self] in
                self?.tapPreviewCell()
            }

            cell.model = model

            baseCell = cell
        }
        
        baseCell.singleTapBlock = { [weak self] in
            self?.tapPreviewCell()
        }
        
        return baseCell
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let c = cell as? PBPreviewBaseCell {
            c.resetSubViewStatusWhenCellEndDisplay()
        }
    }
    
}


/// 下方显示的已选择照片列表

class PBPhotoPreviewSelectedView: UIView, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    
    var bottomBlurView: UIVisualEffectView?
    
    var collectionView: UICollectionView!
    
    var arrSelectedModels: [PBPhotoModel]
    
    var currentShowModel: PBPhotoModel
    
    var selectBlock: ( (PBPhotoModel) -> Void )?
    
    var endSortBlock: ( ([PBPhotoModel]) -> Void )?
    
    var isDraging = false
    
    init(selModels: [PBPhotoModel], currentShowModel: PBPhotoModel) {
        arrSelectedModels = selModels
        self.currentShowModel = currentShowModel
        super.init(frame: .zero)
        setupUI()
    }
    
    func setupUI() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 60, height: 60)
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.scrollDirection = .horizontal
        
        layout.sectionInset = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        addSubview(collectionView)
        
        PBPhotoPreviewSelectedViewCell.pb_register(collectionView)
        
        if #available(iOS 11.0, *) {
            collectionView.dragDelegate = self
            collectionView.dropDelegate = self
            collectionView.dragInteractionEnabled = true
            collectionView.isSpringLoaded = true
        } else {
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction))
            collectionView.addGestureRecognizer(longPressGesture)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        bottomBlurView?.frame = bounds
        collectionView.frame = CGRect(x: 0, y: 10, width: bounds.width, height: 80)
        if let index = arrSelectedModels.firstIndex(where: { $0 == currentShowModel }) {
            collectionView.scrollToItem(at: IndexPath(row: index, section: 0), at: .centeredHorizontally, animated: true)
        }
    }
    
    func currentShowModelChanged(model: PBPhotoModel) {
        guard currentShowModel != model else {
            return
        }
        currentShowModel = model
        
        if let index = arrSelectedModels.firstIndex(where: { $0 == currentShowModel }) {
            collectionView.performBatchUpdates({
                collectionView.scrollToItem(at: IndexPath(row: index, section: 0), at: .centeredHorizontally, animated: true)
            }) { (_) in
                self.collectionView.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
            }
        } else {
            collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
        }
    }
    
    func addSelModel(model: PBPhotoModel) {
        arrSelectedModels.append(model)
        let ip = IndexPath(row: arrSelectedModels.count-1, section: 0)
        collectionView.performBatchUpdates({
            collectionView.insertItems(at: [ip])
        }) { (_) in
            self.collectionView.scrollToItem(at: ip, at: .centeredHorizontally, animated: true)
        }
    }
    
    func removeSelModel(model: PBPhotoModel) {
        guard let index = arrSelectedModels.firstIndex(where: { $0 == model }) else {
            return
        }
        arrSelectedModels.remove(at: index)
        collectionView.performBatchUpdates({
            collectionView.deleteItems(at: [IndexPath(row: index, section: 0)])
        }, completion: nil)
    }
    
    func refreshCell(for model: PBPhotoModel) {
        guard let index = arrSelectedModels.firstIndex(where: { $0 == model }) else {
            return
        }
        collectionView.reloadItems(at: [IndexPath(row: index, section: 0)])
    }
    
    // MARK: iOS10 拖动
    @objc func longPressAction(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            guard let indexPath = collectionView.indexPathForItem(at: gesture.location(in: collectionView)) else {
                return
            }
            isDraging = true
            collectionView.beginInteractiveMovementForItem(at: indexPath)
        } else if gesture.state == .changed {
            collectionView.updateInteractiveMovementTargetPosition(gesture.location(in: collectionView))
        } else if gesture.state == .ended {
            isDraging = false
            collectionView.endInteractiveMovement()
            endSortBlock?(arrSelectedModels)
        } else {
            isDraging = false
            collectionView.cancelInteractiveMovement()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let moveModel = arrSelectedModels[sourceIndexPath.row]
        arrSelectedModels.remove(at: sourceIndexPath.row)
        arrSelectedModels.insert(moveModel, at: destinationIndexPath.row)
    }
    
    // MARK: iOS11 拖动
    @available(iOS 11.0, *)
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        isDraging = true
        let itemProvider = NSItemProvider()
        let item = UIDragItem(itemProvider: itemProvider)
        return [item]
    }
    
    @available(iOS 11.0, *)
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if collectionView.hasActiveDrag {
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UICollectionViewDropProposal(operation: .forbidden)
    }
    
    @available(iOS 11.0, *)
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        isDraging = false
        guard let destinationIndexPath = coordinator.destinationIndexPath else {
            return
        }
        guard let item = coordinator.items.first else {
            return
        }
        guard let sourceIndexPath = item.sourceIndexPath else {
            return
        }
        
        if coordinator.proposal.operation == .move {
            collectionView.performBatchUpdates({
                let moveModel = arrSelectedModels[sourceIndexPath.row]
                
                arrSelectedModels.remove(at: sourceIndexPath.row)
                
                arrSelectedModels.insert(moveModel, at: destinationIndexPath.row)
                
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [destinationIndexPath])
            }, completion: nil)
            
            coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
            
            endSortBlock?(arrSelectedModels)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return arrSelectedModels.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PBPhotoPreviewSelectedViewCell.pb_identifier(), for: indexPath) as! PBPhotoPreviewSelectedViewCell
        
        let m = arrSelectedModels[indexPath.row]
        cell.model = m
        
        if m == currentShowModel {
            cell.layer.borderWidth = 4
        } else {
            cell.layer.borderWidth =  0
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !isDraging else {
            return
        }
        let m = arrSelectedModels[indexPath.row]
        currentShowModel = m
        collectionView.performBatchUpdates({
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }) { (_) in
            collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
        }
        selectBlock?(m)
    }
    
}


class PBPhotoPreviewSelectedViewCell: UICollectionViewCell {
    
    var imageView: UIImageView!
    
    var imageRequestID: PHImageRequestID = PHInvalidImageRequestID
    
    var imageIdentifier: String = ""
    
    var tagImageView: UIImageView!
    
    var tagLabel: UILabel!
    
    var model: PBPhotoModel! {
        didSet {
            configureCell()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.borderColor = UIColor.bottomToolViewBtnNormalBgColor.cgColor
        
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        
        tagImageView = UIImageView()
        tagImageView.contentMode = .scaleAspectFit
        tagImageView.clipsToBounds = true
        contentView.addSubview(tagImageView)
        
        tagLabel = UILabel()
        tagLabel.font = UIFont.systemFont(ofSize: 13)
        tagLabel.textColor = .white
        contentView.addSubview(tagLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        tagImageView.frame = CGRect(x: 5, y: bounds.height-25, width: 20, height: 20)
        tagLabel.frame = CGRect(x: 5, y: bounds.height - 25, width: bounds.width-10, height: 20)
    }
    
    func configureCell() {
        let size = CGSize(width: bounds.width * 1.5, height: bounds.height * 1.5)
        
        if imageRequestID > PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(imageRequestID)
        }
        
        if model.type == .video {
            tagImageView.isHidden = false
            tagImageView.image = getImage("pb_video")
            tagLabel.isHidden = true
        } else if PhotoConfiguration.default().allowSelectGif, model.type == .gif {
            tagImageView.isHidden = true
            tagLabel.isHidden = false
            tagLabel.text = "GIF"
        } else if PhotoConfiguration.default().allowSelectLivePhoto, model.type == .livePhoto {
            tagImageView.isHidden = false
            tagImageView.image = getImage("pb_livePhoto")
            tagLabel.isHidden = true
        } else {
            if let _ =  model.editImage {
                tagImageView.isHidden = false
                tagImageView.image = getImage("pb_editImage_tag")
            } else {
                tagImageView.isHidden = true
                tagLabel.isHidden = true
            }
        }
        
        imageIdentifier = model.ident
        imageView.image = nil
        
        if let ei = model.editImage {
            imageView.image = ei
        } else {
            imageRequestID = PBPhotoManager.fetchImage(for: model.asset, size: size, completion: { [weak self] (image, isDegraded) in
                if self?.imageIdentifier == self?.model.ident {
                    self?.imageView.image = image
                }
            })
        }
    }
    
}
