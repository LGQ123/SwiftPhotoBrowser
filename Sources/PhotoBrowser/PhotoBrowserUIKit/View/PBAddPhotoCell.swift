//
//  PBAddPhotoCell.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import Foundation
import UIKit

class PBAddPhotoCell: UICollectionViewCell {
    var imageView: UIImageView!
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = CGRect(x: 0, y: 0, width: self.bounds.width / 3, height: self.bounds.width / 3)
        imageView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        
    }
    
    func setupUI() {
        layer.masksToBounds = true
        layer.cornerRadius = PhotoConfiguration.default().cellCornerRadio
        
        imageView = UIImageView(image: getImage("pb_addPhoto"))
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        backgroundColor = .cameraCellBgColor
    }
}
