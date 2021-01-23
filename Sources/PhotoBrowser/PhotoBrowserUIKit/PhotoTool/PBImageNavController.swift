//
//  PBImageNavController.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit
import Photos

class PBImageNavController: UINavigationController {

    var isSelectedOriginal: Bool = false
    
    var arrSelectedModels: [PBPhotoModel] = []
    
    var selectImageBlock: ( () -> Void )?
    
    var cancelBlock: ( () -> Void )?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return PhotoConfiguration.default().statusBarStyle
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }
    
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        navigationBar.barStyle = .black
        navigationBar.isTranslucent = true
        modalPresentationStyle = .fullScreen
        isNavigationBarHidden = true
        
        let colorDeploy = PhotoConfiguration.default().themeColorDeploy
        navigationBar.setBackgroundImage(image(color: colorDeploy.navBarColor), for: .default)
        navigationBar.tintColor = colorDeploy.navTitleColor
        navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: colorDeploy.navTitleColor]
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    func image(color: UIColor) -> UIImage? {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor)
        context?.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

}
