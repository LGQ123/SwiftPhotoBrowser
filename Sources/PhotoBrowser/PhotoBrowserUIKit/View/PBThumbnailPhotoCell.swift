//
//  PBThumbnailPhotoCell.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit
import Photos
import PhotoLib
class PBThumbnailPhotoCell: UICollectionViewCell {
    
    var imageView: UIImageView!
    
    var btnSelect: UIButton!
    
    var bottomShadowView: UIImageView!
    
    var videoTag: UIImageView!
    
    var livePhotoTag: UIImageView!
    
    var editImageTag: UIImageView!
    
    var descLabel: UILabel!
    
    var coverView: UIView!
    
    var indexLabel: UILabel!
    
    var enableSelect: Bool = true
    
    var progressView: PBProgressView!
    
    var selectedBlock: ( (Bool) -> Void )?
    
    var model: PBPhotoModel! {
        didSet {
            configureCell()
        }
    }
    
    var index: Int = 0 {
        didSet {
            indexLabel.text = String(index)
        }
    }
    
    var imageIdentifier: String = ""
    
    var smallImageRequestID: PHImageRequestID = PHInvalidImageRequestID
    
    var bigImageReqeustID: PHImageRequestID = PHInvalidImageRequestID
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        
        coverView = UIView()
        coverView.isUserInteractionEnabled = false
        coverView.isHidden = true
        contentView.addSubview(coverView)
        
        btnSelect = UIButton(type: .custom)
        btnSelect.setBackgroundImage(getImage("pb_btn_unselected"), for: .normal)
        btnSelect.setBackgroundImage(getImage("pb_btn_selected"), for: .selected)
        btnSelect.addTarget(self, action: #selector(btnSelectClick), for: .touchUpInside)
        btnSelect.pb_enlargeValidTouchArea(insets: UIEdgeInsets(top: 5, left: 20, bottom: 20, right: 5))
        contentView.addSubview(btnSelect)
        
        indexLabel = UILabel()
        indexLabel.layer.cornerRadius = 23.0 / 2
        indexLabel.layer.masksToBounds = true
        indexLabel.textColor = .white
        indexLabel.font = UIFont.systemFont(ofSize: 14)
        indexLabel.adjustsFontSizeToFitWidth = true
        indexLabel.minimumScaleFactor = 0.5
        indexLabel.textAlignment = .center
        contentView.addSubview(indexLabel)
        
        bottomShadowView = UIImageView(image: getImage("pb_shadow"))
        contentView.addSubview(bottomShadowView)
        
        videoTag = UIImageView(image: getImage("pb_video"))
        bottomShadowView.addSubview(videoTag)
        
        livePhotoTag = UIImageView(image: getImage("pb_livePhoto"))
        bottomShadowView.addSubview(livePhotoTag)
        
        editImageTag = UIImageView(image: getImage("pb_editImage_tag"))
        bottomShadowView.addSubview(editImageTag)
        
        descLabel = UILabel()
        descLabel.font = UIFont.systemFont(ofSize: 13)
        descLabel.textAlignment = .right
        descLabel.textColor = .white
        bottomShadowView.addSubview(descLabel)
        
        progressView = PBProgressView()
        progressView.isHidden = true
        contentView.addSubview(progressView)
        
        if PhotoConfiguration.default().showSelectedBorder {
            layer.borderColor = UIColor.selectedBorderColor.cgColor
        }
    }
    
    override func layoutSubviews() {
        imageView.frame = bounds
        coverView.frame = bounds
        btnSelect.frame = CGRect(x: bounds.width - 30, y: 8, width: 23, height: 23)
        indexLabel.frame = btnSelect.frame
        bottomShadowView.frame = CGRect(x: 0, y: bounds.height - 25, width: bounds.width, height: 25)
        videoTag.frame = CGRect(x: 5, y: 1, width: 20, height: 15)
        livePhotoTag.frame = CGRect(x: 5, y: -1, width: 20, height: 20)
        editImageTag.frame = CGRect(x: 5, y: -1, width: 20, height: 20)
        descLabel.frame = CGRect(x: 30, y: 1, width: bounds.width - 35, height: 17)
        progressView.frame = CGRect(x: (bounds.width - 20)/2, y: (bounds.height - 20)/2, width: 20, height: 20)
        
        super.layoutSubviews()
    }
    
    @objc func btnSelectClick() {
        if !enableSelect, PhotoConfiguration.default().showInvalidMask {
            return
        }
        
        if !btnSelect.isSelected {
            btnSelect.layer.add(getSpringAnimation(), forKey: nil)
        }
        
        selectedBlock?(btnSelect.isSelected)
        
        if btnSelect.isSelected {
            fetchBigImage()
        } else {
            progressView.isHidden = true
            cancelFetchBigImage()
        }
    }
    
    func configureCell() {
        if PhotoConfiguration.default().cellCornerRadio > 0 {
            layer.cornerRadius = PhotoConfiguration.default().cellCornerRadio
            layer.masksToBounds = true
        }
        
        if model.type == .video {
            bottomShadowView.isHidden = false
            videoTag.isHidden = false
            livePhotoTag.isHidden = true
            editImageTag.isHidden = true
            descLabel.text = model.duration
        } else if model.type == .gif {
            bottomShadowView.isHidden = !PhotoConfiguration.default().allowSelectGif
            videoTag.isHidden = true
            livePhotoTag.isHidden = true
            editImageTag.isHidden = true
            descLabel.text = "GIF"
        } else if model.type == .livePhoto {
            bottomShadowView.isHidden = !PhotoConfiguration.default().allowSelectLivePhoto
            videoTag.isHidden = true
            livePhotoTag.isHidden = false
            editImageTag.isHidden = true
            descLabel.text = "Live"
        } else {
            if let _ = model.editImage {
                bottomShadowView.isHidden = false
                videoTag.isHidden = true
                livePhotoTag.isHidden = true
                editImageTag.isHidden = false
                descLabel.text = ""
            } else {
                bottomShadowView.isHidden = true
            }
        }
        
        let showSelBtn: Bool
        if PhotoConfiguration.default().maxSelectCount > 1 {
            if !PhotoConfiguration.default().allowMixSelect {
                showSelBtn = model.type.rawValue < PBPhotoModel.MediaType.video.rawValue
            } else {
                showSelBtn = true
            }
        } else {
            showSelBtn = PhotoConfiguration.default().showSelectBtnWhenSingleSelect
        }
        
        btnSelect.isHidden = !showSelBtn
        btnSelect.isUserInteractionEnabled = showSelBtn
        btnSelect.isSelected = model.isSelected
        
        indexLabel.backgroundColor = .indexLabelBgColor
        
        if model.isSelected {
            fetchBigImage()
        } else {
            cancelFetchBigImage()
        }
        
        if let ei = model.editImage {
            imageView.image = ei
        } else {
            fetchSmallImage()
        }
    }
    
    func fetchSmallImage() {
        let size: CGSize
        let maxSideLength = bounds.width * 1.2
        if model.whRatio > 1 {
            let w = maxSideLength * model.whRatio
            size = CGSize(width: w, height: maxSideLength)
        } else {
            let h = maxSideLength / model.whRatio
            size = CGSize(width: maxSideLength, height: h)
        }
        
        if smallImageRequestID > PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(smallImageRequestID)
        }
        
        imageIdentifier = model.ident
        imageView.image = nil
        smallImageRequestID = PBPhotoManager.fetchImage(for: model.asset, size: size, completion: { [weak self] (image, isDegraded) in
            if self?.imageIdentifier == self?.model.ident {
                self?.imageView.image = image
            }
            if !isDegraded {
                self?.smallImageRequestID = PHInvalidImageRequestID
            }
        })
    }
    
    func fetchBigImage() {
        cancelFetchBigImage()
        
        bigImageReqeustID = PBPhotoManager.fetchOriginalImageData(for: model.asset, progress: { [weak self] (progress, error, _, _) in
            if self?.model.isSelected == true {
                self?.progressView.isHidden = false
                self?.progressView.progress = max(0.1, progress)
                self?.imageView.alpha = 0.5
                if progress >= 1 {
                    self?.resetProgressViewStatus()
                }
            } else {
                self?.cancelFetchBigImage()
            }
        }, completion: { [weak self] (_, _, _) in
            self?.resetProgressViewStatus()
        })
    }
    
    func cancelFetchBigImage() {
        if bigImageReqeustID > PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(bigImageReqeustID)
        }
        resetProgressViewStatus()
    }
    
    func resetProgressViewStatus() {
        progressView.isHidden = true
        imageView.alpha = 1
    }
    
}
