//
//  UIImage+PhotoBrowser.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/5.
//

import UIKit
// MARK: data 转 gif image
extension UIImage {
    
    class func pb_animateGifImage(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let count = CGImageSourceGetCount(source)
        
        let animateImage: UIImage?
        if count <= 1 {
            animateImage = UIImage(data: data)
        } else {
//            var images: [UIImage] = []
//            var duration: Double = 0
//
//            for i in 0..<count {
//                if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
//                    images.append(UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: .up))
//                }
//                duration += UIImage.pb_delayForImageAtIndex(i, source: source)
//            }
//            if duration == 0 {
//                duration = (1.0 / 10.0) * Double(count)
//            }
//            animateImage = UIImage.animatedImage(with: images, duration: duration)
            
            var images = [CGImage]()
            var delays = [Int]()

            for i in 0..<count {
                if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    images.append(image)
                }

                let delaySeconds = UIImage.pb_delayForImageAtIndex(Int(i),
                    source: source)
                delays.append(Int(delaySeconds * 1000.0)) // Seconds to ms
            }

            let duration: Int = {
                var sum = 0

                for val: Int in delays {
                    sum += val
                }

                return sum
            }()

            let gcd = pb_gcdForArray(delays)
            var frames = [UIImage]()

            var frame: UIImage
            var frameCount: Int
            for i in 0..<count {
                frame = UIImage(cgImage: images[Int(i)])
                frameCount = Int(delays[Int(i)] / gcd)

                for _ in 0..<frameCount {
                    frames.append(frame)
                }
            }

            animateImage = UIImage.animatedImage(with: frames,
                duration: Double(duration) / 1000.0)
        }
        
        return animateImage
    }
    
    class func pb_delayForImageAtIndex(_ index: Int, source: CGImageSource!) -> Double {
        var delay = 0.1
        
        let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
        let gifProperties: CFDictionary? = unsafeBitCast(
            CFDictionaryGetValue(cfProperties,
                Unmanaged.passUnretained(kCGImagePropertyGIFDictionary).toOpaque()),
            to: CFDictionary.self)
        
        guard let _ = gifProperties else {
            return 0.1
        }
        
        var delayObject: AnyObject = unsafeBitCast(
            CFDictionaryGetValue(gifProperties!,
                Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()),
            to: AnyObject.self)
        if delayObject.doubleValue == 0 {
            delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties,
                Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()), to: AnyObject.self)
        }
        
        delay = delayObject as! Double
        
        if delay < 0.011 {
            delay = 0.1
        }
        
        return delay
    }
    
    
    class func pb_gcdForArray(_ array: Array<Int>) -> Int {
        if array.isEmpty {
            return 1
        }
        
        var gcd = array[0]
        
        for val in array {
            gcd = UIImage.pb_gcdForPair(val, gcd)
        }
        
        return gcd
    }
    
    class func pb_gcdForPair(_ a1: Int?, _ b1: Int?) -> Int {
        var a = a1
        var b = b1
        if b == nil || a == nil {
            if b != nil {
                return b!
            } else if a != nil {
                return a!
            } else {
                return 0
            }
        }
        
        if a! < b! {
            let c = a
            a = b
            b = c
        }
        
        var rest: Int
        while true {
            rest = a! % b!
            
            if rest == 0 {
                return b!
            } else {
                a = b
                b = rest
            }
        }
    }
    
}


extension UIImage {
    
    // 修复转向
    func fixOrientation() -> UIImage {
        if self.imageOrientation == .up {
            return self
        }
        
        var transform = CGAffineTransform.identity
        
        switch self.imageOrientation {
        case .down, .downMirrored:
            transform = CGAffineTransform(translationX: self.size.width, y: self.size.height)
            transform = transform.rotated(by: .pi)
        
        case .left, .leftMirrored:
            transform = CGAffineTransform(translationX: self.size.width, y: 0)
            transform = transform.rotated(by: CGFloat.pi / 2)
            
        case .right, .rightMirrored:
            transform = CGAffineTransform(translationX: 0, y: self.size.height)
            transform = transform.rotated(by: -CGFloat.pi / 2)
            
        default:
            break
        }
        
        switch self.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: self.size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: self.size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        
        default:
            break
        }
        
        guard let ci = self.cgImage, let colorSpace = ci.colorSpace else {
            return self
        }
        let context = CGContext(data: nil, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: ci.bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: ci.bitmapInfo.rawValue)
        context?.concatenate(transform)
        switch self.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context?.draw(ci, in: CGRect(x: 0, y: 0, width: self.size.height, height: self.size.width))
        default:
            context?.draw(ci, in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        }
        
        guard let newCgimg = context?.makeImage() else {
            return self
        }
        return UIImage(cgImage: newCgimg)
    }

    // 旋转方向
    func rotate(orientation: UIImage.Orientation) -> UIImage {
        guard let imagRef = self.cgImage else {
            return self
        }
        let rect = CGRect(origin: .zero, size: CGSize(width: CGFloat(imagRef.width), height: CGFloat(imagRef.height)))
        
        var bnds = rect
        
        var transform = CGAffineTransform.identity
        
        switch orientation {
        case .up:
            return self
        case .upMirrored:
            transform = transform.translatedBy(x: rect.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .down:
            transform = transform.translatedBy(x: rect.width, y: rect.height)
            transform = transform.rotated(by: .pi)
        case .downMirrored:
            transform = transform.translatedBy(x: 0, y: rect.height)
            transform = transform.scaledBy(x: 1, y: -1)
        case .left:
            bnds = swapRectWidthAndHeight(bnds)
            transform = transform.translatedBy(x: 0, y: rect.width)
            transform = transform.rotated(by: CGFloat.pi * 3 / 2)
        case .leftMirrored:
            bnds = swapRectWidthAndHeight(bnds)
            transform = transform.translatedBy(x: rect.height, y: rect.width)
            transform = transform.scaledBy(x: -1, y: 1)
            transform = transform.rotated(by: CGFloat.pi * 3 / 2)
        case .right:
            bnds = swapRectWidthAndHeight(bnds)
            transform = transform.translatedBy(x: rect.height, y: 0)
            transform = transform.rotated(by: CGFloat.pi / 2)
        case .rightMirrored:
            bnds = swapRectWidthAndHeight(bnds)
            transform = transform.scaledBy(x: -1, y: 1)
            transform = transform.rotated(by: CGFloat.pi / 2)
        @unknown default:
            return self
        }
        
        UIGraphicsBeginImageContext(bnds.size)
        let context = UIGraphicsGetCurrentContext()
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context?.scaleBy(x: -1, y: 1)
            context?.translateBy(x: -rect.height, y: 0)
        default:
            context?.scaleBy(x: 1, y: -1)
            context?.translateBy(x: 0, y: -rect.height)
        }
        context?.concatenate(transform)
        context?.draw(imagRef, in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? self
    }
    
    func swapRectWidthAndHeight(_ rect: CGRect) -> CGRect {
        var r = rect
        r.size.width = rect.height
        r.size.height = rect.width
        return r
    }
    
    func rotate(degress: CGFloat) -> UIImage {
        let rotatedViewBox = UIView(frame: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        let t = CGAffineTransform(rotationAngle: degress)
        rotatedViewBox.transform = t
        let rotatedSize = rotatedViewBox.frame.size

        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap = UIGraphicsGetCurrentContext()

        bitmap?.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)

        bitmap?.rotate(by: degress)

        bitmap?.scaleBy(x: 1.0, y: -1.0)
        guard let cgImg = self.cgImage else {
            return self
        }
        bitmap?.draw(cgImg, in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage ?? self
    }
    
    // 加马赛克
    func mosaicImage() -> UIImage? {
        guard let currCgImage = self.cgImage else {
            return nil
        }
        
        let currCiImage = CIImage(cgImage: currCgImage)
        let filter = CIFilter(name: "CIPixellate")
        filter?.setValue(currCiImage, forKey: kCIInputImageKey)
        filter?.setValue(20, forKey: kCIInputScaleKey)
        guard let outputImage = filter?.outputImage else { return nil }
        
        let context = CIContext()
        
        if let cgImg = context.createCGImage(outputImage, from: CGRect(origin: .zero, size: self.size)) {
            return UIImage(cgImage: cgImg)
        } else {
            return nil
        }
    }
    
    func resize(_ size: CGSize) -> UIImage? {
        if size.width <= 0 || size.height <= 0 {
            return nil
        }
        UIGraphicsBeginImageContextWithOptions(size, false, self.scale)
        self.draw(in: CGRect(origin: .zero, size: size))
        let temp = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return temp
    }
    
    func toCIImage() -> CIImage? {
        var ci = self.ciImage
        if ci == nil, let cg = self.cgImage {
            ci = CIImage(cgImage: cg)
        }
        return ci
    }
    
    func clipImage(_ angle: CGFloat, _ editRect: CGRect) -> UIImage? {
        let a = ((Int(angle) % 360) - 360) % 360
        var newImage = self
        if a == -90 {
            newImage = self.rotate(orientation: .left)
        } else if a == -180 {
            newImage = self.rotate(orientation: .down)
        } else if a == -270 {
            newImage = self.rotate(orientation: .right)
        }
        guard editRect.size != newImage.size else {
            return newImage
        }
        let origin = CGPoint(x: -editRect.minX, y: -editRect.minY)
        UIGraphicsBeginImageContextWithOptions(editRect.size, false, newImage.scale)
        newImage.draw(at: origin)
        let temp = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cgi = temp?.cgImage else {
            return temp
        }
        let clipImage = UIImage(cgImage: cgi, scale: newImage.scale, orientation: .up)
        return clipImage
    }
    
    func blurImage(level: CGFloat) -> UIImage? {
        guard let ciImage = self.toCIImage() else {
            return nil
        }
        let blurFilter = CIFilter(name: "CIGaussianBlur")
        blurFilter?.setValue(ciImage, forKey: "inputImage")
        blurFilter?.setValue(level, forKey: "inputRadius")
        
        guard let outputImage = blurFilter?.outputImage else {
            return nil
        }
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
}


extension CIImage {
    
    func toUIImage() -> UIImage? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(self, from: self.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
}
