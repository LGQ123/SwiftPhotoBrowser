//
//  PBEmbedAlbumListView.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit
import Photos
import PhotoLib
class PBEmbedAlbumListView: UIView {

    static let rowH: CGFloat = 60
    
    var selectedAlbum: PBAlbumListModel
    
    var tableBgView: UIView!
    
    var tableView: UITableView!
    
    var arrDataSource: [PBAlbumListModel] = []
    
    var selectAlbumBlock: ( (PBAlbumListModel) -> Void )?
    
    var hideBlock: ( () -> Void )?
    
    var orientation: UIInterfaceOrientation? = getOrientation()
    
    init(selectedAlbum: PBAlbumListModel) {
        self.selectedAlbum = selectedAlbum
        super.init(frame: .zero)
        setupUI()
        loadAlbumList()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let currOri = getOrientation()
        
        guard currOri != orientation else {
            return
        }
        orientation = currOri
        
        guard !isHidden else {
            return
        }
        
        let bgFrame = calculateBgViewBounds()
        
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: frame.width, height: bgFrame.height), byRoundingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 8, height: 8))
        tableBgView.layer.mask = nil
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        tableBgView.layer.mask = maskLayer
        
        tableBgView.frame = bgFrame
        tableView.frame = tableBgView.bounds
    }
    
    func setupUI() {
        clipsToBounds = true
        
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        tableBgView = UIView()
        addSubview(tableBgView)
        
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .albumListBgColor
        tableView.tableFooterView = UIView()
        tableView.rowHeight = PBEmbedAlbumListView.rowH
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
        tableView.separatorColor = .separatorColor
        tableView.delegate = self
        tableView.dataSource = self
        tableBgView.addSubview(tableView)
        
        PBAlbumListCell.register(tableView)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
    }
    
    func loadAlbumList(completion: ( () -> Void )? = nil) {
        DispatchQueue.global().async {
            PBPhotoModelManager.getPhotoAlbumList(ascending: PhotoConfiguration.default().sortAscending, allowSelectImage: PhotoConfiguration.default().allowSelectImage, allowSelectVideo: PhotoConfiguration.default().allowSelectVideo) { [weak self] (albumList) in
                self?.arrDataSource.removeAll()
                self?.arrDataSource.append(contentsOf: albumList)
                
                DispatchQueue.main.async {
                    completion?()
                    self?.tableView.reloadData()
                }
            }
        }
    }
    
    func calculateBgViewBounds() -> CGRect {
        let contentH = CGFloat(arrDataSource.count) * PBEmbedAlbumListView.rowH
        
        let maxH: CGFloat
        
        if isPortrait() {
            maxH = min(frame.height * 0.7, contentH)
        } else {
            maxH = min(frame.height * 0.8, contentH)
        }
        
        return CGRect(x: 0, y: 0, width: frame.width, height: maxH)
    }
    
    /// 这里不采用监听相册发生变化的方式，是因为每次变化，系统都会回调多次，造成重复获取相册列表
    func show(reloadAlbumList: Bool) {
        func animateShow() {
            let toFrame = calculateBgViewBounds()
            
            isHidden = false
            alpha = 0
            var newFrame = toFrame
            newFrame.origin.y -= newFrame.height
            
            if newFrame != tableBgView.frame {
                let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: newFrame.width, height: newFrame.height), byRoundingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 8, height: 8))
                tableBgView.layer.mask = nil
                let maskLayer = CAShapeLayer()
                maskLayer.path = path.cgPath
                tableBgView.layer.mask = maskLayer
            }
            
            tableBgView.frame = newFrame
            tableView.frame = tableBgView.bounds
            UIView.animate(withDuration: 0.25) {
                self.alpha = 1
                self.tableBgView.frame = toFrame
            }
        }
        
        if reloadAlbumList {
            if #available(iOS 14.0, *), PBPhotoManager.authorizationStatus(for: .readWrite) == .limited {
                loadAlbumList {
                    animateShow()
                }
            } else {
                loadAlbumList()
                animateShow()
            }
        } else {
            animateShow()
        }
    }
    
    func hide() {
        var toFrame = tableBgView.frame
        toFrame.origin.y = -toFrame.height
        
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0
            self.tableBgView.frame = toFrame
        }) { (_) in
            self.isHidden = true
            self.alpha = 1
        }
    }
    
    @objc func tapAction(_ tap: UITapGestureRecognizer) {
        hide()
        hideBlock?()
    }
    
}


extension PBEmbedAlbumListView: UIGestureRecognizerDelegate {
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let p = gestureRecognizer.location(in: self)
        return !tableBgView.frame.contains(p)
    }
    
}


extension PBEmbedAlbumListView: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return arrDataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PBAlbumListCell.identifier(), for: indexPath) as! PBAlbumListCell
        
        let m = arrDataSource[indexPath.row]
        
        cell.configureCell(model: m, style: .embedAlbumList)
        
        cell.selectBtn.isSelected = m == selectedAlbum
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let m = arrDataSource[indexPath.row]
        selectedAlbum = m
        selectAlbumBlock?(m)
        hide()
        if let inx = tableView.indexPathsForVisibleRows {
            tableView.reloadRows(at: inx, with: .none)
        }
    }
    
}
