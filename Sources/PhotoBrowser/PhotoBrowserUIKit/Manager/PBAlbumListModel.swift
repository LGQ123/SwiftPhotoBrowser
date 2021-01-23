//
//  PBAlbumListModel.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/5.
//

import UIKit
import Photos

open class PBAlbumListModel: NSObject {

    public let title: String
    
    open var count: Int {
        return result.count
    }
    
    open var result: PHFetchResult<PHAsset>
    
    public let collection: PHAssetCollection
    
    public let option: PHFetchOptions
    
    public let isCameraRoll: Bool
    
    open var headImageAsset: PHAsset? {
        return result.lastObject
    }
    
    open var models: [PBPhotoModel] = []
    
    // 暂未用到
    open var selectedModels: [PBPhotoModel] = []
    
    // 暂未用到
    open var selectedCount: Int = 0
    
    public init(title: String, result: PHFetchResult<PHAsset>, collection: PHAssetCollection, option: PHFetchOptions, isCameraRoll: Bool) {
        self.title = title
        self.result = result
        self.collection = collection
        self.option = option
        self.isCameraRoll = isCameraRoll
    }
    
    open func refetchPhotos(sortAscending: Bool, allowSelectImage: Bool, allowSelectVideo: Bool) {
        let models = PBPhotoModelManager.fetchPhoto(in: self.result, ascending: sortAscending, allowSelectImage: allowSelectImage, allowSelectVideo:  allowSelectVideo)
        self.models.removeAll()
        self.models.append(contentsOf: models)
    }
    
    func refreshResult() {
        self.result = PHAsset.fetchAssets(in: self.collection, options: self.option)
    }
    
}


public func ==(lhs: PBAlbumListModel, rhs: PBAlbumListModel) -> Bool {
    return lhs.title == rhs.title && lhs.count == rhs.count && lhs.headImageAsset?.localIdentifier == rhs.headImageAsset?.localIdentifier
}
