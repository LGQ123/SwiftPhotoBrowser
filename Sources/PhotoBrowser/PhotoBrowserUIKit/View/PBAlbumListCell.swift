//
//  PBAlbumListCell.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit
import PhotoLib
class PBAlbumListCell: UITableViewCell {

    var coverImageView: UIImageView!
    
    var titleLabel: UILabel!
    
    var countLabel: UILabel!
    
    var selectBtn: UIButton!
    
    var imageIdentifier: String?
    
    var model: PBAlbumListModel!
    
    var style: PhotoBrowserStyle = .embedAlbumList
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let imageViewX: CGFloat
        if style == .embedAlbumList {
            imageViewX = 0
        } else {
            imageViewX = 12
        }
        
        coverImageView.frame = CGRect(x: imageViewX, y: 2, width: bounds.height-4, height: bounds.height-4)
        if let m = model {
            let titleW = min(bounds.width / 3 * 2, m.title.pb_boundingRect(font: UIFont.systemFont(ofSize: 17), limitSize: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 30)).width)
            titleLabel.frame = CGRect(x: coverImageView.frame.maxX + 10, y: (bounds.height - 30)/2, width: titleW, height: 30)
            
            let countSize = ("(" + String(model.count) + ")").pb_boundingRect(font: UIFont.systemFont(ofSize: 17), limitSize: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 30))
            countLabel.frame = CGRect(x: titleLabel.frame.maxX + 10, y: (bounds.height - 30)/2, width: countSize.width, height: 30)
        }
        selectBtn.frame = CGRect(x: bounds.width - 20 - 20, y: (bounds.height - 20) / 2, width: 20, height: 20)
    }
    
    func setupUI() {
        backgroundColor = .albumListBgColor
        selectionStyle = .none
        
        coverImageView = UIImageView()
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        if PhotoConfiguration.default().cellCornerRadio > 0 {
            coverImageView.layer.masksToBounds = true
            coverImageView.layer.cornerRadius = PhotoConfiguration.default().cellCornerRadio
        }
        contentView.addSubview(coverImageView)
        
        titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 17)
        titleLabel.textColor = .albumListTitleColor
        titleLabel.lineBreakMode = .byTruncatingTail
        contentView.addSubview(titleLabel)
        
        countLabel = UILabel()
        countLabel.font = UIFont.systemFont(ofSize: 16)
        countLabel.textColor = .albumListCountColor
        contentView.addSubview(countLabel)
        
        selectBtn = UIButton(type: .custom)
        selectBtn.isUserInteractionEnabled = false
        selectBtn.isHidden = true
        selectBtn.setImage(getImage("pb_albumSelect"), for: .selected)
        contentView.addSubview(selectBtn)
    }
    
    func configureCell(model: PBAlbumListModel, style: PhotoBrowserStyle) {
        self.model = model
        self.style = style
        
        titleLabel.text = model.title
        countLabel.text = "(" + String(model.count) + ")"
        
        if style == .embedAlbumList {
            accessoryType = .none
            selectBtn.isHidden = false
        } else {
            accessoryType = .disclosureIndicator
            selectBtn.isHidden = true
        }
        
        imageIdentifier = model.headImageAsset?.localIdentifier
        if let asset = model.headImageAsset {
            let w = bounds.height * 2.5
            PBPhotoManager.fetchImage(for: asset, size: CGSize(width: w, height: w)) { [weak self] (image, _) in
                if self?.imageIdentifier == self?.model.headImageAsset?.localIdentifier {
                    self?.coverImageView.image = image ?? getImage("pb_defaultphoto")
                }
            }
        }
    }

}
