//
//  PBProgressHUD.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/8.
//

import UIKit

open class PBProgressHUD: UIView {

    public enum HUDStyle: Int {
        
        case light
        
        case lightBlur
        
        case dark
        
        case darkBlur
        
        func bgColor() -> UIColor {
            switch self {
            case .light:
                return .white
            case .dark:
                return .darkGray
            default:
                return .clear
            }
        }
        
        func textColor() -> UIColor {
            switch self {
            case .light, .lightBlur:
                return .black
            case .dark, .darkBlur:
                return .white
            }
        }
        
        func indicatorColor() -> UIColor {
            switch self {
            case .light, .lightBlur:
                return .darkGray
            case .dark, .darkBlur:
                return .white
            }
        }
        
        func blurEffectStyle() -> UIBlurEffect.Style? {
            switch self {
            case .light, .dark:
                return nil
            case .lightBlur:
                return .extraLight
            case .darkBlur:
                return .dark
            }
        }
        
    }
    
    let style: PBProgressHUD.HUDStyle
    
    var timeoutBlock: ( () -> Void )?
    
    var timer: Timer?
    
    deinit {
        self.cleanTimer()
    }
    
    public init(style: PBProgressHUD.HUDStyle) {
        self.style = style
        super.init(frame: UIScreen.main.bounds)
        setupUI()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 110, height: 90))
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.0
        view.backgroundColor = self.style.bgColor()
        view.clipsToBounds = true
        view.alpha = 0.8
        view.center = self.center
        
        if style == .lightBlur || style == .darkBlur {
            let effect = UIBlurEffect(style: self.style.blurEffectStyle()!)
            let effectView = UIVisualEffectView(effect: effect)
            effectView.frame = view.bounds
            view.addSubview(effectView)
        }
        
        let indicator = UIActivityIndicatorView()
        indicator.frame = CGRect(x: (view.bounds.width - indicator.bounds.width)/2, y: 18, width: indicator.bounds.width, height: indicator.bounds.height)
        indicator.color = style.indicatorColor()
        indicator.startAnimating()
        view.addSubview(indicator)
        
        let label = UILabel(frame: CGRect(x: 0, y: 50, width: view.bounds.width, height: 30))
        label.textAlignment = .center
        label.textColor = style.textColor()
        label.font = UIFont.systemFont(ofSize: 16)
        label.text = "正在处理"
        view.addSubview(label)
        
        self.addSubview(view)
    }
    
    @objc public func show(timeout: TimeInterval = 100) {
        DispatchQueue.main.async {
            UIApplication.shared.windows.first?.addSubview(self)
        }
        if timeout > 0 {
            cleanTimer()
            timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(timeout(_:)), userInfo: nil, repeats: false)
            RunLoop.current.add(timer!, forMode: .default)
        }
    }
    
    @objc public func hide() {
        cleanTimer()
        DispatchQueue.main.async {
            self.removeFromSuperview()
        }
    }
    
    @objc func timeout(_ timer: Timer) {
        timeoutBlock?()
        hide()
    }
    
    func cleanTimer() {
        timer?.invalidate()
        timer = nil
    }
    
}
