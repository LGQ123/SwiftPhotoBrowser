//
//  Filter.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2020/12/31.
//

import UIKit

public typealias PBFilterApplierType = ((_ image: UIImage) -> UIImage)

public enum PBFilterType: Int {
    case normal
    case chrome
    case fade
    case instant
    case process
    case transfer
    case tone
    case linear
    case sepia
    case mono
    case noir
    case tonal
    
    var coreImageFilterName: String {
        switch self {
        case .normal:
            return ""
        case .chrome:
            return "CIPhotoEffectChrome"
        case .fade:
            return "CIPhotoEffectFade"
        case .instant:
            return "CIPhotoEffectInstant"
        case .process:
            return "CIPhotoEffectProcess"
        case .transfer:
            return "CIPhotoEffectTransfer"
        case .tone:
            return "CILinearToSRGBToneCurve"
        case .linear:
            return "CISRGBToneCurveToLinear"
        case .sepia:
            return "CISepiaTone"
        case .mono:
            return "CIPhotoEffectMono"
        case .noir:
            return "CIPhotoEffectNoir"
        case .tonal:
            return "CIPhotoEffectTonal"
        }
    }
}

@objcMembers
@objc(SwiftPBFilter)
open class PBFilter: NSObject {
    
    let name: String
    
    let applier: PBFilterApplierType?
    
    public init(name: String, filterType: PBFilterType) {
        self.name = name
        
        if filterType != .normal {
            self.applier = { image -> UIImage in
                guard let ciImage = image.toCIImage() else {
                    return image
                }
                
                let filter = CIFilter(name: filterType.coreImageFilterName)
                filter?.setValue(ciImage, forKey: kCIInputImageKey)
                guard let outputImage = filter?.outputImage?.toUIImage() else {
                    return image
                }
                return outputImage
            }
        } else {
            self.applier = nil
        }
    }
    
    /// 可传入 applier 自定义滤镜
    public init(name: String, applier: PBFilterApplierType?) {
        self.name = name
        self.applier = applier
    }
    
}


extension PBFilter {
    
    class func clarendonFilter(image: UIImage) -> UIImage {
        guard let ciImage = image.toCIImage() else {
            return image
        }
        
        let backgroundImage = self.getColorImage(red: 127, green: 187, blue: 227, alpha: Int(255 * 0.2),
                                            rect: ciImage.extent)
        let outputCIImage = ciImage.applyingFilter("CIOverlayBlendMode", parameters: [
            "inputBackgroundImage": backgroundImage
            ])
            .applyingFilter("CIColorControls", parameters: [
                "inputSaturation": 1.35,
                "inputBrightness": 0.05,
                "inputContrast": 1.1
                ])
        guard let outputImage = outputCIImage.toUIImage() else {
            return image
        }
        return outputImage
    }
    
    class func nashvilleFilter(image: UIImage) -> UIImage {
        guard let ciImage = image.toCIImage() else {
            return image
        }
        
        let backgroundImage = getColorImage(red: 247, green: 176, blue: 153, alpha: Int(255 * 0.56),
                                            rect: ciImage.extent)
        let backgroundImage2 = getColorImage(red: 0, green: 70, blue: 150, alpha: Int(255 * 0.4),
                                             rect: ciImage.extent)
        let outputCIImage = ciImage
            .applyingFilter("CIDarkenBlendMode", parameters: [
                "inputBackgroundImage": backgroundImage
                ])
            .applyingFilter("CISepiaTone", parameters: [
                "inputIntensity": 0.2
                ])
            .applyingFilter("CIColorControls", parameters: [
                "inputSaturation": 1.2,
                "inputBrightness": 0.05,
                "inputContrast": 1.1
                ])
            .applyingFilter("CILightenBlendMode", parameters: [
                "inputBackgroundImage": backgroundImage2
                ])
        
        guard let outputImage = outputCIImage.toUIImage() else {
            return image
        }
        return outputImage
    }
    
    class func apply1977Filter(image: UIImage) -> UIImage {
        guard let ciImage = image.toCIImage() else {
            return image
        }
        
        let filterImage = getColorImage(red: 243, green: 106, blue: 188, alpha: Int(255 * 0.1), rect: ciImage.extent)
        let backgroundImage = ciImage
            .applyingFilter("CIColorControls", parameters: [
                "inputSaturation": 1.3,
                "inputBrightness": 0.1,
                "inputContrast": 1.05
                ])
            .applyingFilter("CIHueAdjust", parameters: [
                "inputAngle": 0.3
                ])
        
        let outputCIImage = filterImage
            .applyingFilter("CIScreenBlendMode", parameters: [
                "inputBackgroundImage": backgroundImage
                ])
            .applyingFilter("CIToneCurve", parameters: [
                "inputPoint0": CIVector(x: 0, y: 0),
                "inputPoint1": CIVector(x: 0.25, y: 0.20),
                "inputPoint2": CIVector(x: 0.5, y: 0.5),
                "inputPoint3": CIVector(x: 0.75, y: 0.80),
                "inputPoint4": CIVector(x: 1, y: 1)
                ])
        
        guard let outputImage = outputCIImage.toUIImage() else {
            return image
        }
        return outputImage
    }
    
    class func toasterFilter(image: UIImage) -> UIImage {
        guard let ciImage = image.toCIImage() else {
            return image
        }
        
        let width = ciImage.extent.width
        let height = ciImage.extent.height
        let centerWidth = width / 2.0
        let centerHeight = height / 2.0
        let radius0 = min(width / 4.0, height / 4.0)
        let radius1 = min(width / 1.5, height / 1.5)
        
        let color0 = self.getColor(red: 128, green: 78, blue: 15, alpha: 255)
        let color1 = self.getColor(red: 79, green: 0, blue: 79, alpha: 255)
        let circle = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: centerWidth, y: centerHeight),
            "inputRadius0": radius0,
            "inputRadius1": radius1,
            "inputColor0": color0,
            "inputColor1": color1
            ])?.outputImage?.cropped(to: ciImage.extent)
        
        let outputCIImage = ciImage
            .applyingFilter("CIColorControls", parameters: [
                "inputSaturation": 1.0,
                "inputBrightness": 0.01,
                "inputContrast": 1.1
                ])
            .applyingFilter("CIScreenBlendMode", parameters: [
                "inputBackgroundImage": circle!
                ])
        
        guard let outputImage = outputCIImage.toUIImage() else {
            return image
        }
        return outputImage
    }
    
    class func getColor(red: Int, green: Int, blue: Int, alpha: Int = 255) -> CIColor {
        return CIColor(red: CGFloat(Double(red) / 255.0),
                       green: CGFloat(Double(green) / 255.0),
                       blue: CGFloat(Double(blue) / 255.0),
                       alpha: CGFloat(Double(alpha) / 255.0))
    }
    
    class func getColorImage(red: Int, green: Int, blue: Int, alpha: Int = 255, rect: CGRect) -> CIImage {
        let color = self.getColor(red: red, green: green, blue: blue, alpha: alpha)
        return CIImage(color: color).cropped(to: rect)
    }
    
}


public extension PBFilter {
    
    static let all: [PBFilter] = [.normal, .clarendon, .nashville, .apply1977, .toaster, .chrome, .fade, .instant, .process, .transfer, .tone, .linear, .sepia, .mono, .noir, .tonal]
    
    static let normal = PBFilter(name: "无滤镜", filterType: .normal)
    
    static let clarendon = PBFilter(name: "强化", applier: PBFilter.clarendonFilter)
    
    static let nashville = PBFilter(name: "温暖", applier: PBFilter.nashvilleFilter)
    
    static let apply1977 = PBFilter(name: "1977", applier: PBFilter.apply1977Filter)
    
    static let toaster = PBFilter(name: "时光", applier: PBFilter.toasterFilter)
    
    static let chrome = PBFilter(name: "铬黄", filterType: .chrome)
    
    static let fade = PBFilter(name: "褪色", filterType: .fade)
    
    static let instant = PBFilter(name: "瞬间", filterType: .instant)
    
    static let process = PBFilter(name: "自然", filterType: .process)
    
    static let transfer = PBFilter(name: "明亮", filterType: .transfer)
    
    static let tone = PBFilter(name: "调和", filterType: .tone)
    
    static let linear = PBFilter(name: "线性", filterType: .linear)
    
    static let sepia = PBFilter(name: "深褐", filterType: .sepia)
    
    static let mono = PBFilter(name: "单色", filterType: .mono)
    
    static let noir = PBFilter(name: "单色黑", filterType: .noir)
    
    static let tonal = PBFilter(name: "单色白", filterType: .tonal)
    
}
