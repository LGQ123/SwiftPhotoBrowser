//
//  PBFetchImageOperation.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit
import Photos
import PhotoLib
class PBFetchImageOperation: Operation {

    let model: PBPhotoModel
    
    let isOriginal: Bool
    
    let progress: (PHAssetImageProgressHandler)?
    
    let completion: ( (UIImage?, PHAsset?) -> Void )
    
    var pri_isExecuting = false {
        willSet {
            willChangeValue(forKey: "isExecuting")
        }
        didSet {
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    override var isExecuting: Bool {
        return pri_isExecuting
    }
    
    var pri_isFinished = false {
        willSet {
            willChangeValue(forKey: "isFinished")
        }
        didSet {
            didChangeValue(forKey: "isFinished")
        }
    }
    
    override var isFinished: Bool {
        return pri_isFinished
    }
    
    var pri_isCancelled = false {
        willSet {
            willChangeValue(forKey: "isCancelled")
        }
        didSet {
            didChangeValue(forKey: "isCancelled")
        }
    }

    override var isCancelled: Bool {
        return pri_isCancelled
    }
    
    init(model: PBPhotoModel, isOriginal: Bool, progress: (PHAssetImageProgressHandler)? = nil, completion: @escaping ( (UIImage?, PHAsset?) -> Void )) {
        self.model = model
        self.isOriginal = isOriginal
        self.progress = progress
        self.completion = completion
        super.init()
    }
    
    override func start() {
        if isCancelled {
            fetchFinish()
            return
        }
        pri_isExecuting = true
        
        // 存在编辑的图片
        if let ei = model.editImage {
            if PhotoConfiguration.default().saveNewImageAfterEdit {
                PBPhotoManager.saveImageToAlbum(image: ei) { [weak self] (suc, asset) in
                    self?.completion(ei, asset)
                    self?.fetchFinish()
                }
            } else {
                DispatchQueue.main.async {
                    self.completion(ei, nil)
                    self.fetchFinish()
                }
            }
            return
        }
        
        if PhotoConfiguration.default().allowSelectGif, model.type == .gif {
            PBPhotoManager.fetchOriginalImageData(for: model.asset) { [weak self] (data, _, isDegraded) in
                if !isDegraded {
                    let image = UIImage.animateGifImage(data: data)
                    self?.completion(image, nil)
                    self?.fetchFinish()
                }
            }
            return
        }
        
        if isOriginal {
            PBPhotoManager.fetchOriginalImage(for: model.asset, progress: progress) { [weak self] (image, isDegraded) in
                if !isDegraded {
                    self?.completion(image?.fixOrientation(), nil)
                    self?.fetchFinish()
                }
            }
        } else {
            PBPhotoManager.fetchImage(for: model.asset, size: model.previewSize, progress: progress) { [weak self] (image, isDegraded) in
                if !isDegraded {
                    self?.completion(self?.scaleImage(image?.fixOrientation()), nil)
                    self?.fetchFinish()
                }
            }
        }
    }
    
    func scaleImage(_ image: UIImage?) -> UIImage? {
        guard let i = image else { return nil }
        guard let data = i.jpegData(compressionQuality: 1) else { return i }
        let mUnit: CGFloat = 1024 * 1024
        
        if data.count < Int(0.2 * mUnit) { return i }
        let scale: CGFloat = (data.count > Int(mUnit) ? 0.5 : 0.7)
        
        guard let d = i.jpegData(compressionQuality: scale) else { return i }
        return UIImage(data: d)
    }
    
    func fetchFinish() {
        pri_isExecuting = false
        pri_isFinished = true
    }
    
    override func cancel() {
        super.cancel()
        pri_isCancelled = true
    }
    
}
