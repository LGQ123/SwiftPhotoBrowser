//
//  PBProgressView.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit

class PBProgressView: UIView {

    private var progressLayer: CAShapeLayer!
    
    var progress: CGFloat = 0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .clear
        progressLayer = CAShapeLayer()
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.white.cgColor
        progressLayer.lineCap = .round
        progressLayer.lineWidth = 4
        
        layer.addSublayer(progressLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = rect.width / 2
        let end = -(.pi / 2) + (.pi * 2 * progress)
        progressLayer.frame = bounds
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: -(.pi / 2), endAngle: end, clockwise: true)
        progressLayer.path = path.cgPath
    }
    
}
