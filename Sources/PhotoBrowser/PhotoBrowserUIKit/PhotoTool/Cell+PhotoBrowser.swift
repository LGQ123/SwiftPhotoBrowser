//
//  Cell+PhotoBrowser.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit

extension UICollectionViewCell {
    
    class func identifier() -> String {
        return NSStringFromClass(self.classForCoder())
    }
    
    class func register(_ collectionView: UICollectionView) {
        collectionView.register(self.classForCoder(), forCellWithReuseIdentifier: self.identifier())
    }
    
}

extension UITableViewCell {
    
    class func identifier() -> String {
        return NSStringFromClass(self.classForCoder())
    }
    
    class func register(_ tableView: UITableView) {
        tableView.register(self.classForCoder(), forCellReuseIdentifier: self.identifier())
    }
    
}
