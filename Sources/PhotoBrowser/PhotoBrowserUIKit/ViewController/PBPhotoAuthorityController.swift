//
//  PBPhotoAuthorityController.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/23.
//

import UIKit

class PBPhotoAuthorityController: UIViewController {
    
    
    private var cancelBtn: UIButton!
    private var contentLabel: UILabel!
    private var settingBtn: UIButton!
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return PhotoConfiguration.default().statusBarStyle
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        var insets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        if #available(iOS 11.0, *) {
            insets = view.safeAreaInsets
        }
        cancelBtn.frame = CGRect(x: view.frame.width - 60, y: insets.top, width: 60, height: 44)
        contentLabel.frame = CGRect(x: 40, y: 150, width: view.frame.width - 80, height: 200)
        settingBtn.frame = CGRect(x: view.frame.width / 2 - 60, y: 400, width: 120, height: 44)
    }
    
    func setupUI() {
        view.backgroundColor =  .thumbnailBgColor
        
        contentLabel = UILabel()
        contentLabel.font = PBLayout.navTitleFont
        contentLabel.text = String(format: "无法访问照片，请在iPhone的\"设置-隐私-照片\"选项中，允许%@访问你的照片", getAppName())
        contentLabel.textAlignment = .center
        contentLabel.numberOfLines = 0
        contentLabel.textColor = .navTitleColor
        view.addSubview(contentLabel)
        
        cancelBtn = UIButton(type: .custom)
        cancelBtn.titleLabel?.font = PBLayout.navTitleFont
        cancelBtn.setTitle("取消", for: .normal)
        cancelBtn.setTitleColor(.navTitleColor, for: .normal)
        cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        view.addSubview(cancelBtn)
        
        
        
        settingBtn = UIButton(type: .custom)
        settingBtn.titleLabel?.font = PBLayout.bottomToolTitleFont
        settingBtn.setTitle("前往系统设置", for: .normal)
        settingBtn.setTitleColor(.bottomToolViewBtnNormalTitleColor, for: .normal)
        if PhotoConfiguration.default().clickStyle == .clip {
            settingBtn.setBackgroundImage(getImage("pb_btn_rrc"), for: .normal)
        } else {
            settingBtn.backgroundColor = .bottomToolViewBtnNormalBgColor
        }
        settingBtn.layer.masksToBounds = true
        settingBtn.layer.cornerRadius = PBLayout.bottomToolBtnCornerRadius
        settingBtn.addTarget(self, action: #selector(settingBtnClick), for: .touchUpInside)
        view.addSubview(settingBtn)
    }
    
    @objc func cancelBtnClick() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func settingBtnClick() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    
}
