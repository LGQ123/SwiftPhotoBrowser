//
//  PBTextStickerView.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/5.
//

import UIKit

protocol PBTextStickerViewDelegate: PBStickerViewDelegate {
    
    func sticker(_ textSticker: PBTextStickerView, editText text: String)
    
}

class PBTextStickerView: UIView, PBStickerViewAdditional {

    static let edgeInset: CGFloat = 10
    
    static let fontSize: CGFloat = PhotoConfiguration.default().textStickerFontSize
    
    static let borderWidth = 1 / UIScreen.main.scale
    
    weak var delegate: PBTextStickerViewDelegate?
    
    var firstLayout = true
    
    var gesIsEnabled = true
    
    let originScale: CGFloat
    
    let originAngle: CGFloat
    
    var originFrame: CGRect
    
    var originTransform: CGAffineTransform = .identity
    
    var text: String {
        didSet {
            label.text = text
        }
    }
    
    var textColor: UIColor {
        didSet {
            label.textColor = textColor
        }
    }
    
    // TODO: add text background color
    var bgColor: UIColor {
        didSet {
            label.backgroundColor = bgColor
        }
    }
    
    var borderView: UIView!
    
    var label: UILabel!
    
    var pinchGes: UIPinchGestureRecognizer!
    
    var tapGes: UITapGestureRecognizer!
    
    var panGes: UIPanGestureRecognizer!
    
    var timer: Timer?
    
    var totalTranslationPoint: CGPoint = .zero
    
    var gesTranslationPoint: CGPoint = .zero
    
    var gesRotation: CGFloat = 0
    
    var gesScale: CGFloat = 1
    
    var onOperation = false
    
    // Conver all states to model.
    var state: PBTextStickerState {
        return PBTextStickerState(text: text, textColor: textColor, bgColor: bgColor, originScale: originScale, originAngle: originAngle, originFrame: originFrame, gesScale: gesScale, gesRotation: gesRotation, totalTranslationPoint: totalTranslationPoint)
    }
    
    deinit {
        cleanTimer()
    }
    
    convenience init(from state: PBTextStickerState) {
        self.init(text: state.text, textColor: state.textColor, bgColor: state.bgColor, originScale: state.originScale, originAngle: state.originAngle, originFrame: state.originFrame, gesScale: state.gesScale, gesRotation: state.gesRotation, totalTranslationPoint: state.totalTranslationPoint, showBorder: false)
    }
    
    init(text: String, textColor: UIColor, bgColor: UIColor, originScale: CGFloat, originAngle: CGFloat, originFrame: CGRect, gesScale: CGFloat = 1, gesRotation: CGFloat = 0, totalTranslationPoint: CGPoint = .zero, showBorder: Bool = true) {
        self.originScale = originScale
        self.text = text
        self.textColor = textColor
        self.bgColor = bgColor
        self.originAngle = originAngle
        self.originFrame = originFrame
        
        super.init(frame: .zero)
        
        self.gesScale = gesScale
        self.gesRotation = gesRotation
        self.totalTranslationPoint = totalTranslationPoint
        
        borderView = UIView()
        borderView.layer.borderWidth = PBTextStickerView.borderWidth
        hideBorder()
        if showBorder {
            startTimer()
        }
        addSubview(borderView)
        
        label = UILabel()
        label.text = text
        label.font = UIFont.boldSystemFont(ofSize: PBTextStickerView.fontSize)
        label.textColor = textColor
        label.backgroundColor = bgColor
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        borderView.addSubview(label)
        
        tapGes = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        addGestureRecognizer(tapGes)
        
        pinchGes = UIPinchGestureRecognizer(target: self, action: #selector(pinchAction(_:)))
        pinchGes.delegate = self
        addGestureRecognizer(pinchGes)
        
        let rotationGes = UIRotationGestureRecognizer(target: self, action: #selector(rotationAction(_:)))
        rotationGes.delegate = self
        addGestureRecognizer(rotationGes)
        
        panGes = UIPanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        panGes.delegate = self
        addGestureRecognizer(panGes)
        
        tapGes.require(toFail: panGes)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard firstLayout else {
            return
        }
        
        // Rotate must be first when first layout.
        transform = transform.rotated(by: originAngle.pb_toPi)
        
        if totalTranslationPoint != .zero {
            if originAngle == 90 {
                transform = transform.translatedBy(x: totalTranslationPoint.y, y: -totalTranslationPoint.x)
            } else if originAngle == 180 {
                transform = transform.translatedBy(x: -totalTranslationPoint.x, y: -totalTranslationPoint.y)
            } else if originAngle == 270 {
                transform = transform.translatedBy(x: -totalTranslationPoint.y, y: totalTranslationPoint.x)
            } else {
                transform = transform.translatedBy(x: totalTranslationPoint.x, y: totalTranslationPoint.y)
            }
        }
        
        transform = transform.scaledBy(x: originScale, y: originScale)
        
        originTransform = transform
        
        if gesScale != 1 {
            transform = transform.scaledBy(x: gesScale, y: gesScale)
        }
        if gesRotation != 0 {
            transform = transform.rotated(by: gesRotation)
        }
        
        firstLayout = false
        borderView.frame = bounds.insetBy(dx: PBTextStickerView.edgeInset, dy: PBTextStickerView.edgeInset)
        label.frame = borderView.bounds.insetBy(dx: PBTextStickerView.edgeInset, dy: PBTextStickerView.edgeInset)
    }
    
    @objc func tapAction(_ ges: UITapGestureRecognizer) {
        guard gesIsEnabled else { return }
        
        if let t = timer, t.isValid {
            delegate?.sticker(self, editText: text)
        } else {
            superview?.bringSubviewToFront(self)
            delegate?.stickerDidTap(self)
            startTimer()
        }
    }
    
    @objc func pinchAction(_ ges: UIPinchGestureRecognizer) {
        guard gesIsEnabled else { return }
        
        gesScale *= ges.scale
        ges.scale = 1
        
        if ges.state == .began {
            setOperation(true)
        } else if ges.state == .changed {
            updateTransform()
        } else if (ges.state == .ended || ges.state == .cancelled){
            setOperation(false)
        }
    }
    
    @objc func rotationAction(_ ges: UIRotationGestureRecognizer) {
        guard gesIsEnabled else { return }
        
        gesRotation += ges.rotation
        ges.rotation = 0
        
        if ges.state == .began {
            setOperation(true)
        } else if ges.state == .changed {
            updateTransform()
        } else if (ges.state == .ended || ges.state == .cancelled){
            setOperation(false)
        }
    }
    
    @objc func panAction(_ ges: UIPanGestureRecognizer) {
        guard gesIsEnabled else { return }
        
        let point = ges.translation(in: superview)
        gesTranslationPoint = CGPoint(x: point.x / originScale, y: point.y / originScale)
        
        if ges.state == .began {
            setOperation(true)
        } else if ges.state == .changed {
            updateTransform()
        } else if (ges.state == .ended || ges.state == .cancelled) {
            totalTranslationPoint.x += point.x
            totalTranslationPoint.y += point.y
            setOperation(false)
            if originAngle == 90 {
                originTransform = originTransform.translatedBy(x: gesTranslationPoint.y, y: -gesTranslationPoint.x)
            } else if originAngle == 180 {
                originTransform = originTransform.translatedBy(x: -gesTranslationPoint.x, y: -gesTranslationPoint.y)
            } else if originAngle == 270 {
                originTransform = originTransform.translatedBy(x: -gesTranslationPoint.y, y: gesTranslationPoint.x)
            } else {
                originTransform = originTransform.translatedBy(x: gesTranslationPoint.x, y: gesTranslationPoint.y)
            }
            gesTranslationPoint = .zero
        }
    }
    
    func setOperation(_ isOn: Bool) {
        if isOn, !onOperation {
            onOperation = true
            cleanTimer()
            borderView.layer.borderColor = UIColor.white.cgColor
            superview?.bringSubviewToFront(self)
            delegate?.stickerBeginOperation(self)
        } else if !isOn, onOperation {
            onOperation = false
            startTimer()
            delegate?.stickerEndOperation(self, panGes: panGes)
        }
    }
    
    func updateTransform() {
        var transform = originTransform
        
        if originAngle == 90 {
            transform = transform.translatedBy(x: gesTranslationPoint.y, y: -gesTranslationPoint.x)
        } else if originAngle == 180 {
            transform = transform.translatedBy(x: -gesTranslationPoint.x, y: -gesTranslationPoint.y)
        } else if originAngle == 270 {
            transform = transform.translatedBy(x: -gesTranslationPoint.y, y: gesTranslationPoint.x)
        } else {
            transform = transform.translatedBy(x: gesTranslationPoint.x, y: gesTranslationPoint.y)
        }
        // Scale must after translate.
        transform = transform.scaledBy(x: gesScale, y: gesScale)
        // Rotate must after scale.
        transform = transform.rotated(by: gesRotation)
        self.transform = transform
        
        delegate?.stickerOnOperation(self, panGes: panGes)
    }
    
    @objc func hideBorder() {
        borderView.layer.borderColor = UIColor.clear.cgColor
    }
    
    func startTimer() {
        cleanTimer()
        borderView.layer.borderColor = UIColor.white.cgColor
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false, block: { (_) in
            self.hideBorder()
            self.cleanTimer()
        })
        RunLoop.current.add(timer!, forMode: .default)
    }
    
    func cleanTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func resetState() {
        onOperation = false
        cleanTimer()
        hideBorder()
    }
    
    func moveToAshbin() {
        cleanTimer()
        removeFromSuperview()
    }
    
    func addScale(_ scale: CGFloat) {
        // Revert zoom scale.
        transform = transform.scaledBy(x: 1/originScale, y: 1/originScale)
        // Revert ges scale.
        transform = transform.scaledBy(x: 1/gesScale, y: 1/gesScale)
        // Revert ges rotation.
        transform = transform.rotated(by: -gesRotation)
        
        var origin = frame.origin
        origin.x *= scale
        origin.y *= scale
        
        let newSize = CGSize(width: frame.width * scale, height: frame.height * scale)
        let newOrigin = CGPoint(x: frame.minX + (frame.width - newSize.width)/2, y: frame.minY + (frame.height - newSize.height)/2)
        let diffX: CGFloat = (origin.x - newOrigin.x)
        let diffY: CGFloat = (origin.y - newOrigin.y)
        
        if originAngle == 90 {
            transform = transform.translatedBy(x: diffY, y: -diffX)
            originTransform = originTransform.translatedBy(x: diffY / originScale, y: -diffX / originScale)
        } else if originAngle == 180 {
            transform = transform.translatedBy(x: -diffX, y: -diffY)
            originTransform = originTransform.translatedBy(x: -diffX / originScale, y: -diffY / originScale)
        } else if originAngle == 270 {
            transform = transform.translatedBy(x: -diffY, y: diffX)
            originTransform = originTransform.translatedBy(x: -diffY / originScale, y: diffX / originScale)
        } else {
            transform = transform.translatedBy(x: diffX, y: diffY)
            originTransform = originTransform.translatedBy(x: diffX / originScale, y: diffY / originScale)
        }
        totalTranslationPoint.x += diffX
        totalTranslationPoint.y += diffY
        
        transform = transform.scaledBy(x: scale, y: scale)
        
        // Readd zoom scale.
        transform = transform.scaledBy(x: originScale, y: originScale)
        // Readd ges scale.
        transform = transform.scaledBy(x: gesScale, y: gesScale)
        // Readd ges rotation.
        transform = transform.rotated(by: gesRotation)
        
        gesScale *= scale
    }
    
    func changeSize(to newSize: CGSize) {
        // Revert zoom scale.
        transform = transform.scaledBy(x: 1/originScale, y: 1/originScale)
        // Revert ges scale.
        transform = transform.scaledBy(x: 1/gesScale, y: 1/gesScale)
        // Revert ges rotation.
        transform = transform.rotated(by: -gesRotation)
        transform = transform.rotated(by: -originAngle.pb_toPi)
        
        // Recalculate current frame.
        let center = CGPoint(x: frame.midX, y: frame.midY)
        var frame = self.frame
        frame.origin.x = center.x - newSize.width / 2
        frame.origin.y = center.y - newSize.height / 2
        frame.size = newSize
        self.frame = frame
        
        let oc = CGPoint(x: originFrame.midX, y: originFrame.midY)
        var of = originFrame
        of.origin.x = oc.x - newSize.width / 2
        of.origin.y = oc.y - newSize.height / 2
        of.size = newSize
        originFrame = of
        
        borderView.frame = bounds.insetBy(dx: PBTextStickerView.edgeInset, dy: PBTextStickerView.edgeInset)
        label.frame = borderView.bounds.insetBy(dx: PBTextStickerView.edgeInset, dy: PBTextStickerView.edgeInset)
        
        // Readd zoom scale.
        transform = transform.scaledBy(x: originScale, y: originScale)
        // Readd ges scale.
        transform = transform.scaledBy(x: gesScale, y: gesScale)
        // Readd ges rotation.
        transform = transform.rotated(by: gesRotation)
        transform = transform.rotated(by: originAngle.pb_toPi)
    }
    
    class func calculateSize(text: String, width: CGFloat) -> CGSize {
        let diff = PBTextStickerView.edgeInset * 2
        let size = text.pb_boundingRect(font: UIFont.boldSystemFont(ofSize: PBTextStickerView.fontSize), limitSize: CGSize(width: width - diff, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: size.width + diff * 2, height: size.height + diff * 2)
    }
    
}


extension PBTextStickerView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
}

public class PBTextStickerState: NSObject {
    
    let text: String
    let textColor: UIColor
    let bgColor: UIColor
    let originScale: CGFloat
    let originAngle: CGFloat
    let originFrame: CGRect
    let gesScale: CGFloat
    let gesRotation: CGFloat
    let totalTranslationPoint: CGPoint
    
    init(text: String, textColor: UIColor, bgColor: UIColor, originScale: CGFloat, originAngle: CGFloat, originFrame: CGRect, gesScale: CGFloat, gesRotation: CGFloat, totalTranslationPoint: CGPoint) {
        self.text = text
        self.textColor = textColor
        self.bgColor = bgColor
        self.originScale = originScale
        self.originAngle = originAngle
        self.originFrame = originFrame
        self.gesScale = gesScale
        self.gesRotation = gesRotation
        self.totalTranslationPoint = totalTranslationPoint
        super.init()
    }
    
}
