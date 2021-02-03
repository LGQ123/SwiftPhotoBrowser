//
//  PBPhotoManager.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/5.
//

import UIKit
import Photos
import PhotosUI

@objcMembers
@objc(SwiftPBPhotoManager)
open class PBPhotoManager: NSObject {
    
    /// 保存图像到相册
    /// - Parameters:
    ///   - image: 需要保存的图片
    ///   - completion: Bool 是否成功， PHAsset 成功的Asset
    open class func saveImageToAlbum(image: UIImage, completion: ( (Bool, PHAsset?) -> Void )? ) {
        
        if !havePhotoLibratyAuthority() {
            completion?(false, nil)
            return
        }
        
        var placeholderAsset: PHObjectPlaceholder? = nil
        PHPhotoLibrary.shared().performChanges({
            let newAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            placeholderAsset = newAssetRequest.placeholderForCreatedAsset
        }) { (suc, error) in
            DispatchQueue.main.async {
                if suc {
                    let asset = self.getAsset(from: placeholderAsset?.localIdentifier)
                    completion?(suc, asset)
                } else {
                    completion?(false, nil)
                }
            }
        }
    }
    
    /// 保存视频到相册.
    /// - Parameters:
    ///   - url: 保存视频URL
    ///   - completion: Bool 成功 ，PHAsset成功Asset
    open class func saveVideoToAlbum(url: URL, completion: ( (Bool, PHAsset?) -> Void )? ) {
        
        if !havePhotoLibratyAuthority() {
            completion?(false, nil)
            return
        }
        
        var placeholderAsset: PHObjectPlaceholder? = nil
        PHPhotoLibrary.shared().performChanges({
            let newAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            placeholderAsset = newAssetRequest?.placeholderForCreatedAsset
        }) { (suc, error) in
            DispatchQueue.main.async {
                if suc {
                    let asset = self.getAsset(from: placeholderAsset?.localIdentifier)
                    completion?(suc, asset)
                } else {
                    completion?(false, nil)
                }
            }
        }
    }
    
    private class func getAsset(from localIdentifier: String?) -> PHAsset? {
        guard let id = localIdentifier else {
            return nil
        }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        if result.count > 0{
            return result[0]
        }
        return nil
    }
    
    
    
    
    /// 获取相册列表
    /// - Parameters:
    ///   - ascending: 排序
    ///   - allowSelectImage: 是否选图片
    ///   - allowSelectVideo:  是否选视频
    ///   - completion: Bool 是否成功 ，[PHFetchResult<PHCollection>]
     open class func getPhotoAlbumList(ascending: Bool, allowSelectImage: Bool, allowSelectVideo: Bool, completion: ( (Bool, [PHFetchResult<PHCollection>]?) -> Void )) {
        
        if !havePhotoLibratyAuthority() {
            completion(false, nil)
            return
        }
        
        let option = PHFetchOptions()
        if !allowSelectImage {
            option.predicate = NSPredicate(format: "mediaType == %ld", PHAssetMediaType.video.rawValue)
        }
        if !allowSelectVideo {
            option.predicate = NSPredicate(format: "mediaType == %ld", PHAssetMediaType.image.rawValue)
        }
        
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil) as! PHFetchResult<PHCollection>
        let streamAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumMyPhotoStream, options: nil) as! PHFetchResult<PHCollection>
        let userAlbums = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        let syncedAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumSyncedAlbum, options: nil) as! PHFetchResult<PHCollection>
        let sharedAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: nil) as! PHFetchResult<PHCollection>
        let arr = [smartAlbums, streamAlbums, userAlbums, syncedAlbums, sharedAlbums]
        completion(true, arr)
    }
    
    /// 获取相片数据
    /// - Parameters:
    ///   - allowSelectImage: 是否选照片
    ///   - allowSelectVideo: 是否选视频
    ///   - completion:Bool 是否成功 ，PHAssetCollection，PHFetchResult<PHAsset> ，PHFetchOptions
    open class func getCameraRollAlbum(allowSelectImage: Bool, allowSelectVideo: Bool, completion: @escaping ( (Bool, PHAssetCollection?, PHFetchResult<PHAsset>?, PHFetchOptions?) -> Void )) {
        
        if !havePhotoLibratyAuthority() {
            completion(false, nil, nil, nil)
            return
        }
        let option = PHFetchOptions()
        if !allowSelectImage {
            option.predicate = NSPredicate(format: "mediaType == %ld", PHAssetMediaType.video.rawValue)
        }
        if !allowSelectVideo {
            option.predicate = NSPredicate(format: "mediaType == %ld", PHAssetMediaType.image.rawValue)
        }
        
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
        smartAlbums.enumerateObjects { (collection, _, stop) in
            if collection.assetCollectionSubtype == .smartAlbumUserLibrary {
                let result = PHAsset.fetchAssets(in: collection, options: option)
                completion(true, collection,result,option)
                stop.pointee = true
            }
        }
    }
    
    /// 标题.
    /// - Parameter collection: PHAssetCollection
    /// - Returns: 标题
    open class func getCollectionTitle(_ collection: PHAssetCollection) -> String {
        if collection.assetCollectionType == .album {
            // Albums created by user.
            var title: String? = nil
            switch collection.assetCollectionSubtype {
            case .albumMyPhotoStream:
                title = "我的照片流"
            default:
                title = collection.localizedTitle
            }
            
            return title ?? "所有照片"
        }
        
        var title: String? = nil
        
        switch collection.assetCollectionSubtype {
        case .smartAlbumUserLibrary:
            title = "所有照片"
        case .smartAlbumPanoramas:
            title = "全景照片"
        case .smartAlbumVideos:
            title = "视频"
        case .smartAlbumFavorites:
            title = "个人收藏"
        case .smartAlbumTimelapses:
            title = "延时摄影"
        case .smartAlbumRecentlyAdded:
            title = "最近添加"
        case .smartAlbumBursts:
            title = "连拍快照"
        case .smartAlbumSlomoVideos:
            title = "慢动作"
        case .smartAlbumSelfPortraits:
            title = "自拍"
        case .smartAlbumScreenshots:
            title = "屏幕快照"
        case .smartAlbumDepthEffect:
            title = "人像"
        case .smartAlbumLivePhotos:
            title = "Live Photo"
        default:
            title = collection.localizedTitle
        }
        
        if #available(iOS 11.0, *) {
            if collection.assetCollectionSubtype == PHAssetCollectionSubtype.smartAlbumAnimated {
                title = "动图"
            }
        }
        return title ?? "所有照片"
    }
    
    
    /// 获取图片
    /// - Parameters:
    ///   - asset: PHAsset
    ///   - size: 返回图片的大小
    ///   - progress: 进度回调
    ///   - completion: 下载完成回调 返回图片  是否是低质量
    /// - Returns: 请求的数字标识符。如果需要在请求完成之前取消请求，请将此标识符传递给cancelImageRequest:方法。
    @discardableResult
    open class func fetchImage(for asset: PHAsset, size: CGSize, progress: (PHAssetImageProgressHandler)? = nil, completion: @escaping ( (UIImage?, Bool) -> Void )) -> PHImageRequestID {
        return self.fetchImage(for: asset, size: size, resizeMode: .fast, progress: progress, completion: completion)
    }
    
    /// 获取原图
    /// - Parameters:
    ///   - asset: PHAsset
    ///   - progress: 进度回调
    ///   - completion: 下载完成回调 返回图片  是否是低质量
    /// - Returns: 请求的数字标识符。如果需要在请求完成之前取消请求，请将此标识符传递给cancelImageRequest:方法。
    @discardableResult
    open class func fetchOriginalImage(for asset: PHAsset, progress: (PHAssetImageProgressHandler)? = nil, completion: @escaping ( (UIImage?, Bool) -> Void)) -> PHImageRequestID {
        return self.fetchImage(for: asset, size: PHImageManagerMaximumSize, resizeMode: .fast, progress: progress, completion: completion)
    }
    
    /// 获取 asset data.
    /// - Parameters:
    ///   - asset: PHAsset
    ///   - progress: 进度回调
    ///   - completion: 下载完成回调 返回图片data  是否是低质量
    /// - Returns: 请求的数字标识符。如果需要在请求完成之前取消请求，请将此标识符传递给cancelImageRequest:方法。
    @discardableResult
    open class func fetchOriginalImageData(for asset: PHAsset, progress: (PHAssetImageProgressHandler)? = nil, completion: @escaping ( (Data, [AnyHashable: Any]?, Bool) -> Void)) -> PHImageRequestID {
        let option = PHImageRequestOptions()
        if (asset.value(forKey: "filename") as? String)?.hasSuffix("GIF") == true {
            option.version = .original
        }
        option.isNetworkAccessAllowed = true
        option.resizeMode = .fast
        option.deliveryMode = .highQualityFormat
        option.progressHandler = { (pro, error, stop, info) in
            DispatchQueue.main.async {
                progress?(pro, error, stop, info)
            }
        }
        
        if #available(iOS 13, *) {
            return PHImageManager.default().requestImageDataAndOrientation(for: asset, options: option) { (data, _, _, info) in
                let cancel = info?[PHImageCancelledKey] as? Bool ?? false
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool ?? false)
                if !cancel, let data = data {
                    completion(data, info, isDegraded)
                }
            }
        } else {
            return PHImageManager.default().requestImageData(for: asset, options: option) { (data, _, _, info) in
                let cancel = info?[PHImageCancelledKey] as? Bool ?? false
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool ?? false)
                if !cancel, let data = data {
                    completion(data, info, isDegraded)
                }
            }
        }
    }
    
    /// 获取LivePhoto
    /// - Parameters:
    ///   - asset: PHAsset
    ///   - completion: 下载完成回调 返回LivePhoto   是否是低质量
    /// - Returns: 请求的数字标识符。如果需要在请求完成之前取消请求，请将此标识符传递给cancelImageRequest:方法。
    @discardableResult
    open class func fetchLivePhoto(for asset: PHAsset, completion: @escaping ( (PHLivePhoto?, [AnyHashable: Any]?, Bool) -> Void )) -> PHImageRequestID {
        let option = PHLivePhotoRequestOptions()
        option.version = .current
        option.deliveryMode = .opportunistic
        option.isNetworkAccessAllowed = true
        
        return PHImageManager.default().requestLivePhoto(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: option) { (livePhoto, info) in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool ?? false)
            completion(livePhoto, info, isDegraded)
        }
    }
    
    /// 获取视频
    /// - Parameters:
    ///   - asset: PHAsset
    ///   - progress: 进度回调
    ///   - completion: 下载完成回调 返回AVPlayerItem  info  是否是低质量
    /// - Returns: 请求的数字标识符。如果需要在请求完成之前取消请求，请将此标识符传递给cancelImageRequest:方法。
    @discardableResult
    open class func fetchVideo(for asset: PHAsset, progress: (PHAssetImageProgressHandler)? = nil, completion: @escaping ( (AVPlayerItem?, [AnyHashable: Any]?, Bool) -> Void )) -> PHImageRequestID {
        let option = PHVideoRequestOptions()
        option.isNetworkAccessAllowed = true
        option.progressHandler = { (pro, error, stop, info) in
            DispatchQueue.main.async {
                progress?(pro, error, stop, info)
            }
        }
        
        if asset.isInCloud {
            return PHImageManager.default().requestExportSession(forVideo: asset, options: option, exportPreset: AVAssetExportPresetHighestQuality, resultHandler: { (session, info) in
                // iOS11 and earlier, callback is not on the main thread.
                DispatchQueue.main.async {
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool ?? false)
                    if let avAsset = session?.asset {
                        let item = AVPlayerItem(asset: avAsset)
                        completion(item, info, isDegraded)
                    }
                }
            })
        } else {
            return PHImageManager.default().requestPlayerItem(forVideo: asset, options: option) { (item, info) in
                // iOS11 and earlier, callback is not on the main thread.
                DispatchQueue.main.async {
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool ?? false)
                    completion(item, info, isDegraded)
                }
            }
        }
    }
    
    /// 获取图片.
    private class func fetchImage(for asset: PHAsset, size: CGSize, resizeMode: PHImageRequestOptionsResizeMode, progress: (PHAssetImageProgressHandler)? = nil, completion: @escaping ( (UIImage?, Bool) -> Void )) -> PHImageRequestID {
        let option = PHImageRequestOptions()
        option.resizeMode = resizeMode
        option.isNetworkAccessAllowed = true
        option.progressHandler = { (pro, error, stop, info) in
            DispatchQueue.main.async {
                progress?(pro, error, stop, info)
            }
        }
        
        return PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: option) { (image, info) in
            var downloadFinished = false
            if let info = info {
                downloadFinished = !(info[PHImageCancelledKey] as? Bool ?? false) && (info[PHImageErrorKey] == nil)
            }
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool ?? false)
            if downloadFinished {
                completion(image, isDegraded)
            }
        }
    }
    
    open class func isFetchImageError(_ error: Error?) -> Bool {
        guard let e = error as NSError? else {
            return false
        }
        if e.domain == "CKErrorDomain" || e.domain == "CloudPhotoLibraryErrorDomain" {
            return true
        }
        return false
    }
    
    open class func fetchAVAsset(forVideo asset: PHAsset, completion: @escaping ( (AVAsset?, [AnyHashable: Any]?) -> Void )) -> PHImageRequestID {
        let options = PHVideoRequestOptions()
        options.version = .original
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed =  true
        if asset.isInCloud {
            return PHImageManager.default().requestExportSession(forVideo: asset, options: options, exportPreset: AVAssetExportPresetHighestQuality) { (session, info) in
                // iOS11 and earlier, callback is not on the main thread.
                DispatchQueue.main.async {
                    if let avAsset = session?.asset {
                        completion(avAsset, info)
                    }
                }
            }
        } else {
            return PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { (avAsset, _, info) in
                DispatchQueue.main.async {
                    completion(avAsset, info)
                }
            }
        }
    }
    
    /// 获取 asset 本地路径.
    open class func fetchAssetFilePath(asset: PHAsset, completion: @escaping (String?) -> Void ) {
        asset.requestContentEditingInput(with: nil) { (input, info) in
            var path = input?.fullSizeImageURL?.absoluteString
            if path == nil, let dir = asset.value(forKey: "directory") as? String, let name = asset.value(forKey: "filename") as? String {
                path = String(format: "file:///var/mobile/Media/%@/%@", dir, name)
            }
            completion(path)
        }
    }
}


public extension PBPhotoManager {
    
    
    /// 是否授权相册
    /// - Returns: 是否授权相册
    class func havePhotoLibratyAuthority() -> Bool {
        
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .denied || status == .restricted || status == .notDetermined {
            return false
        }
        return true
    }
    
    /// 返回权限状态
    /// - Returns: PHAuthorizationStatus
    class func authorizationStatus() -> PHAuthorizationStatus {
        let status = PHPhotoLibrary.authorizationStatus()
        return status
    }
    
    /// Replaces \c +authorizationStatus to support add-only/read-write access level status
    @available(iOS 14, *)
    class func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: accessLevel)
        return status
    }
    
    /// 授权
    /// - Parameter handler: PHAuthorizationStatus
    class func requestAuthorization(_ handler: @escaping (PHAuthorizationStatus) -> Void) {
        let status = PBPhotoManager.authorizationStatus()
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { (status) in
                DispatchQueue.main.async {
                    handler(status)
                }
            }
        } else {
            handler(status)
        }
    }
    
    /// 注册 observer
    /// - Parameter observer: PHPhotoLibraryChangeObserver
    class func register(_ observer: PHPhotoLibraryChangeObserver) {
        PHPhotoLibrary.shared().register(observer)
    }
    
    /// 取消 observer
    /// - Parameter observer: PHPhotoLibraryChangeObserver
    class func unregisterChangeObserver(_ observer: PHPhotoLibraryChangeObserver) {
        PHPhotoLibrary.shared().unregisterChangeObserver(observer)
    }
    
    
    /// iOS14 打开有限选择
    /// - Parameter controller: 从哪个controller打开
    @available(iOS 14, *)
    class func presentLimitedLibraryPicker(from controller: UIViewController) {
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
    }
}

extension PHAsset {
    
    var isInCloud: Bool {
        guard let resource = PHAssetResource.assetResources(for: self).first else {
            return false
        }
        return !(resource.value(forKey: "locallyAvailable") as? Bool ?? true)
    }
    
}
