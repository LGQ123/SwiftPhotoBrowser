//
//  Cell+PhotoBrowser.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit

extension UICollectionViewCell {
    
    class func pb_identifier() -> String {
        return NSStringFromClass(self.classForCoder())
    }
    
    class func pb_register(_ collectionView: UICollectionView) {
        collectionView.register(self.classForCoder(), forCellWithReuseIdentifier: self.pb_identifier())
    }
    
}

extension UITableViewCell {
    
    class func pb_identifier() -> String {
        return NSStringFromClass(self.classForCoder())
    }
    
    class func pb_register(_ tableView: UITableView) {
        tableView.register(self.classForCoder(), forCellReuseIdentifier: self.pb_identifier())
    }
    
}
