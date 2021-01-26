//
//  PBAlbumListController.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit
import Photos
import PhotoLib
class PBAlbumListController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var navView: UIView!
    
    var navBlurView: UIVisualEffectView?
    
    var albumTitleLabel: UILabel!
    
    var cancelBtn: UIButton!
    
    var tableView: UITableView!
    
    var arrDataSource: [PBAlbumListModel] = []
    
    var shouldReloadAlbumList = true
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return PhotoConfiguration.default().statusBarStyle
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        PBPhotoManager.register(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        
        guard shouldReloadAlbumList else { return }
        
        DispatchQueue.global().async {
            PBPhotoModelManager.getPhotoAlbumList(ascending: PhotoConfiguration.default().sortAscending, allowSelectImage: PhotoConfiguration.default().allowSelectImage, allowSelectVideo: PhotoConfiguration.default().allowSelectVideo) { [weak self] (albumList) in
                self?.arrDataSource.removeAll()
                self?.arrDataSource.append(contentsOf: albumList)
                
                self?.shouldReloadAlbumList = false
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            }
        }
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
        
        navView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: insets.top + navViewNormalH)
        navBlurView?.frame = navView.bounds
        
        let albumTitleW: CGFloat = 40.0
        albumTitleLabel.frame = CGRect(x: (view.frame.width-albumTitleW)/2, y: insets.top, width: albumTitleW, height: 44)
        let cancelBtnW: CGFloat = 60.0
        cancelBtn.frame = CGRect(x: view.frame.width-insets.right-cancelBtnW, y: insets.top, width: cancelBtnW, height: 44)
        
        tableView.frame = CGRect(x: insets.left, y: 0, width: view.frame.width - insets.left - insets.right, height: view.frame.height)
        tableView.contentInset = UIEdgeInsets(top: collectionViewInsetTop, left: 0, bottom: 0, right: 0)
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: 44, left: 0, bottom: 0, right: 0)
    }
    
    func setupUI() {
        view.backgroundColor = .albumListBgColor
        
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .albumListBgColor
        tableView.tableFooterView = UIView()
        tableView.rowHeight = 65
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
        tableView.separatorColor = .separatorColor
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
        
        PBAlbumListCell.register(tableView)
        
        if #available(iOS 11.0, *) {
            tableView.contentInsetAdjustmentBehavior = .always
        }
        
        navView = UIView()
        navView.backgroundColor = .navBarColor
        view.addSubview(navView)
        
        if let effect = PhotoConfiguration.default().navViewBlurEffect {
            navBlurView = UIVisualEffectView(effect: effect)
            navView.addSubview(navBlurView!)
        }
        
        albumTitleLabel = UILabel()
        albumTitleLabel.textColor = .navTitleColor
        albumTitleLabel.font = PBLayout.navTitleFont
        albumTitleLabel.text = "照片"
        albumTitleLabel.textAlignment = .center
        navView.addSubview(albumTitleLabel)
        
        cancelBtn = UIButton(type: .custom)
        cancelBtn.titleLabel?.font = PBLayout.navTitleFont
        cancelBtn.setTitle("取消", for: .normal)
        cancelBtn.setTitleColor(.navTitleColor, for: .normal)
        cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        navView.addSubview(cancelBtn)
    }
    
    @objc func cancelBtnClick() {
        let nav = navigationController as? PBImageNavController
        nav?.cancelBlock?()
        nav?.dismiss(animated: true, completion: nil)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return arrDataSource.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PBAlbumListCell.identifier(), for: indexPath) as! PBAlbumListCell
        
        cell.configureCell(model: arrDataSource[indexPath.row], style: .externalAlbumList)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc = PBThumbnailViewController(albumList: arrDataSource[indexPath.row])
        show(vc, sender: nil)
    }

}


extension PBAlbumListController: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        shouldReloadAlbumList = true
    }
    
}
