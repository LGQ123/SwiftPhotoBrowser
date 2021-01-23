//
//  PBPhotoModel.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/5.
//

import UIKit
import Photos

public extension PBPhotoModel {
    
    enum MediaType: Int {
        case unknown = 0
        case image
        case gif
        case livePhoto
        case video
    }
    
}


open class PBPhotoModel: NSObject {

    public let ident: String
    
    public let asset: PHAsset
    
    open var type: PBPhotoModel.MediaType = .unknown
    
    open var duration: String = ""
    
    open var isSelected: Bool = false
    
    private var pri_editImage: UIImage? = nil
    open var editImage: UIImage? {
        set {
            pri_editImage = newValue
        }
        get {
            if let _ = editImageModel {
                return pri_editImage
            } else {
                return nil
            }
        }
    }
    
    open var second: Int {
        guard type == .video else {
            return 0
        }
        return Int(round(asset.duration))
    }
    
    open var whRatio: CGFloat {
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }
    
    open var previewSize: CGSize {
        let scale: CGFloat = 2 //UIScreen.main.scale
        if whRatio > 1 {
            let h = min(UIScreen.main.bounds.height, PBMaxImageWidth) * scale
            let w = h * whRatio
            return CGSize(width: w, height: h)
        } else {
            let w = min(UIScreen.main.bounds.width, PBMaxImageWidth) * scale
            let h = w / whRatio
            return CGSize(width: w, height: h)
        }
    }
    
    // 最后一次编辑
    open var editImageModel: PBEditImageModel?
    
    public init(asset: PHAsset) {
        ident = asset.localIdentifier
        self.asset = asset
        super.init()
        
        type = transformAssetType(for: asset)
        if type == .video {
            duration = transformDuration(for: asset)
        }
    }
    
    open func transformAssetType(for asset: PHAsset) -> PBPhotoModel.MediaType {
        switch asset.mediaType {
        case .video:
            return .video
        case .image:
            if (asset.value(forKey: "filename") as? String)?.hasSuffix("GIF") == true {
                return .gif
            }
            if #available(iOS 9.1, *) {
                if asset.mediaSubtypes == .photoLive || asset.mediaSubtypes.rawValue == 10 {
                    return .livePhoto
                }
            }
            return .image
        default:
            return .unknown
        }
    }
    
    open func transformDuration(for asset: PHAsset) -> String {
        let dur = Int(round(asset.duration))
        
        switch dur {
        case 0..<60:
            return String(format: "00:%02d", dur)
        case 60..<3600:
            let m = dur / 60
            let s = dur % 60
            return String(format: "%02d:%02d", m, s)
        case 3600...:
            let h = dur / 3600
            let m = (dur % 3600) / 60
            let s = dur % 60
            return String(format: "%02d:%02d:%02d", h, m, s)
        default:
            return ""
        }
    }
    
}


public func ==(lhs: PBPhotoModel, rhs: PBPhotoModel) -> Bool {
    return lhs.ident == rhs.ident
}
