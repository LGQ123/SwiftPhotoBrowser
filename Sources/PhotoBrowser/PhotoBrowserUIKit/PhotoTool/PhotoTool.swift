//
//  PhotoTool.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2020/12/30.
//

import UIKit


let PBMaxImageWidth: CGFloat = 600

func RGB(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
    return UIColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
}

func getAppName() -> String {
    if let name = Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String {
        return name
    }
    if let name = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String {
        return name
    }
    if let name = Bundle.main.infoDictionary?["CFBundleName"] as? String {
        return name
    }
    return "App"
}

func isIPhoneXSeries() -> Bool {
    var iPhoneXSeries: Bool = false
    let mainWindow: UIWindow = UIApplication.shared.windows.last!
    if #available(iOS 11.0, *) {
        if mainWindow.safeAreaInsets.bottom > 0 {
            iPhoneXSeries = true
        }
    }
    return iPhoneXSeries
}

func deviceIsiPhone() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .phone
}

func deviceIsiPad() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}
func deviceSafeAreaInsets() -> UIEdgeInsets {
    var insets: UIEdgeInsets = .zero
    
    if #available(iOS 11, *) {
        insets = UIApplication.shared.windows.first?.safeAreaInsets ?? .zero
    }
    
    return insets
}

func getSpringAnimation() -> CAKeyframeAnimation {
    let animate = CAKeyframeAnimation(keyPath: "transform")
    animate.duration = 0.3
    animate.isRemovedOnCompletion = true
    animate.fillMode = .forwards
    
    animate.values = [CATransform3DMakeScale(0.7, 0.7, 1),
                      CATransform3DMakeScale(1.2, 1.2, 1),
                      CATransform3DMakeScale(0.8, 0.8, 1),
                      CATransform3DMakeScale(1, 1, 1)]
    return animate
}

func getImage(_ named: String) -> UIImage? {
    return UIImage(named: named, in: Bundle.pb_module, compatibleWith: nil)
//    return UIImage(named: named)
}

func isLandscape() -> Bool {
    if #available(iOS 13.0, *) {
        return UIApplication.shared.windows
            .first?
            .windowScene?
            .interfaceOrientation
            .isLandscape ?? false
    } else {
       return  UIApplication.shared.statusBarOrientation.isLandscape
    }
}

func isPortrait() -> Bool {
    if #available(iOS 13.0, *) {
        return UIApplication.shared.windows
            .first?
            .windowScene?
            .interfaceOrientation
            .isPortrait ?? false
    } else {
       return  UIApplication.shared.statusBarOrientation.isPortrait
    }
}

func getOrientation() -> UIInterfaceOrientation? {
    if #available(iOS 13.0, *) {
        return UIApplication.shared.windows
            .first?
            .windowScene?
            .interfaceOrientation
    } else {
       return  UIApplication.shared.statusBarOrientation
    }
}

struct PBLayout {
    
    static let navTitleFont = UIFont.systemFont(ofSize: 17)
    
    static let bottomToolViewH: CGFloat = 55
    
    static let bottomToolBtnH: CGFloat = 34
    
    static let bottomToolTitleFont = UIFont.systemFont(ofSize: 17)
    
    static let bottomToolBtnCornerRadius: CGFloat = 5
    
    static let thumbCollectionViewItemSpacing: CGFloat = 2
    
    static let thumbCollectionViewLineSpacing: CGFloat = 2
    
}

func showAlertView(_ message: String, _ sender: UIViewController?) {
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    let action = UIAlertAction(title: "确定", style: .default, handler: nil)
    alert.addAction(action)
    if deviceIsiPad() {
        alert.popoverPresentationController?.sourceView = sender?.view
    }
    (sender ?? UIApplication.shared.windows.first?.rootViewController)?.showDetailViewController(alert, sender: nil)
}

func canAddModel(_ model: PBPhotoModel, currentSelectCount: Int, sender: UIViewController?, showAlert: Bool = true) -> Bool {
    guard (PhotoConfiguration.default().canSelectAsset?(model.asset) ?? true) else {
        return false
    }
    
    if currentSelectCount >= PhotoConfiguration.default().maxSelectCount {
        if showAlert {
            let message = String(format: "最多只能选择%ld张图片", PhotoConfiguration.default().maxSelectCount)
            showAlertView(message, sender)
        }
        return false
    }
    if currentSelectCount > 0 {
        if !PhotoConfiguration.default().allowMixSelect, model.type == .video {
            return false
        }
    }
    if model.type == .video {
        if model.second > PhotoConfiguration.default().maxSelectVideoDuration {
            if showAlert {
                let message = String(format: "不能选择超过%ld秒的视频", PhotoConfiguration.default().maxSelectVideoDuration)
                showAlertView(message, sender)
            }
            return false
        }
        if model.second < PhotoConfiguration.default().minSelectVideoDuration {
            if showAlert {
                let message = String(format: "不能选择低于%ld秒的视频", PhotoConfiguration.default().minSelectVideoDuration)
                showAlertView(message, sender)
            }
            return false
        }
    }
    return true
}

func markSelected(source: inout [PBPhotoModel], selected: inout [PBPhotoModel]) {
    guard selected.count > 0 else {
        return
    }
    
    var selIds: [String: Bool] = [:]
    var selEditImage: [String: UIImage] = [:]
    var selEditModel: [String: PBEditImageModel] = [:]
    var selIdAndIndex: [String: Int] = [:]
    
    for (index, m) in selected.enumerated() {
        selIds[m.ident] = true
        selEditImage[m.ident] = m.editImage
        selEditModel[m.ident] = m.editImageModel
        selIdAndIndex[m.ident] = index
    }
    
    source.forEach { (m) in
        if selIds[m.ident] == true {
            m.isSelected = true
            m.editImage = selEditImage[m.ident]
            m.editImageModel = selEditModel[m.ident]
            selected[selIdAndIndex[m.ident]!] = m
        } else {
            m.isSelected = false
        }
    }
}

extension Bundle {
    static var pb_module: Bundle? = {
        let bundleName = "PhotoBrowser"

        var candidates = [
            // Bundle should be present here when the package is linked into an App.
            Bundle.main.resourceURL,

            // Bundle should be present here when the package is linked into a framework.
//            Bundle(for: PBPhotoPreviewSheet.self).resourceURL,

            // For command-line tools.
            Bundle.main.bundleURL,
        ]
        
//        #if SWIFT_PACKAGE
//        // For SWIFT_PACKAGE.
        candidates.append(Bundle.module.bundleURL)
//        #endif

        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }
        return nil
    }()
}

extension CGFloat {
    var pb_toPi: CGFloat {
        return self / 180 * .pi
    }
}

extension Int {
    init(_ bool:Bool) {
        self = bool ? 1 : 0
    }
}

extension Array where Element: Equatable {
    func pb_removeDuplicate() -> Array {
        return self.enumerated().filter { (index, value) -> Bool in
            return self.firstIndex(of: value) == index
        }.map { (_, value) in
            return value
        }
    }
}

extension String {
    func pb_boundingRect(font: UIFont, limitSize: CGSize) -> CGSize {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byCharWrapping
        
        let att = [NSAttributedString.Key.font: font, NSAttributedString.Key.paragraphStyle: style]
        
        let attContent = NSMutableAttributedString(string: self, attributes: att)
        
        let size = attContent.boundingRect(with: limitSize, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).size
        
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
}

