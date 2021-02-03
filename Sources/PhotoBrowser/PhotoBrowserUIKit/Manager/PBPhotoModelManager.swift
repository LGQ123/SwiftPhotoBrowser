//
//  PBPhotoModelManager.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/22.
//

import Photos
import PhotoLib

class PBPhotoModelManager: NSObject {
    
    /// 获取相机相册 ->PBAlbumListModel
     public class func getCameraRollAlbum(allowSelectImage: Bool, allowSelectVideo: Bool, completion: @escaping ( (PBAlbumListModel) -> Void )) {
        
        PBPhotoManager.getCameraRollAlbum(allowSelectImage: allowSelectImage, allowSelectVideo: allowSelectVideo) { (success, collection, result, option) in
            
            if !success {
                return
            }
            let albumModel = PBAlbumListModel(title: PBPhotoManager.getCollectionTitle(collection!), result: result!, collection: collection!, option: option!, isCameraRoll: true)
            completion(albumModel)
        }
        
        
    }
    
    /// 获取某个PHFetchResult照片 - >. PBPhotoModel
    public class func fetchPhoto(in result: PHFetchResult<PHAsset>, ascending: Bool, allowSelectImage: Bool, allowSelectVideo: Bool, limitCount: Int = .max) -> [PBPhotoModel] {
        var models: [PBPhotoModel] = []
        let option: NSEnumerationOptions = ascending ? .init(rawValue: 0) : .reverse
        var count = 1
        
        result.enumerateObjects(options: option) { (asset, index, stop) in
            let m = PBPhotoModel(asset: asset)
            
            if m.type == .image, !allowSelectImage {
                return
            }
            if m.type == .video, !allowSelectVideo {
                return
            }
            if count == limitCount {
                stop.pointee = true
            }
            
            models.append(m)
            count += 1
        }
        
        return models
    }
    
    public class func getPhotoAlbumList(ascending: Bool, allowSelectImage: Bool, allowSelectVideo: Bool, completion: ( ([PBAlbumListModel]) -> Void )) {
        let option = PHFetchOptions()
        if !allowSelectImage {
            option.predicate = NSPredicate(format: "mediaType == %ld", PHAssetMediaType.video.rawValue)
        }
        if !allowSelectVideo {
            option.predicate = NSPredicate(format: "mediaType == %ld", PHAssetMediaType.image.rawValue)
        }
        PBPhotoManager.getPhotoAlbumList(ascending: ascending, allowSelectImage: allowSelectImage, allowSelectVideo: allowSelectVideo) { (success,arr) in
            if !success {
                return
            }
            var albumList: [PBAlbumListModel] = []
            arr!.forEach { (album) in
                album.enumerateObjects { (collection, _, _) in
                    guard let collection = collection as? PHAssetCollection else { return }
                    if collection.assetCollectionSubtype == .smartAlbumAllHidden {
                        return
                    }
                    if #available(iOS 11.0, *), collection.assetCollectionSubtype.rawValue > PHAssetCollectionSubtype.smartAlbumLongExposures.rawValue {
                        return
                    }
                    let result = PHAsset.fetchAssets(in: collection, options: option)
                    if result.count == 0 {
                        return
                    }
                    let title = PBPhotoManager.getCollectionTitle(collection)
                    
                    if collection.assetCollectionSubtype == .smartAlbumUserLibrary {
                        // Album of all photos.
                        let m = PBAlbumListModel(title: title, result: result, collection: collection, option: option, isCameraRoll: true)
                        albumList.insert(m, at: 0)
                    } else {
                        let m = PBAlbumListModel(title: title, result: result, collection: collection, option: option, isCameraRoll: false)
                        albumList.append(m)
                    }
                }
            }
            completion(albumList)
        }
    }
    
}

