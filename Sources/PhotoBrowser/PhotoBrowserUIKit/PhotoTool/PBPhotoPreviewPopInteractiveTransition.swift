//
//  PBPhotoPreviewPopInteractiveTransition.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit

class PBPhotoPreviewPopInteractiveTransition: UIPercentDrivenInteractiveTransition {
    
    weak var transitionContext: UIViewControllerContextTransitioning?
    
    weak var viewController: PBPhotoPreviewController?
    
    var shadowView: UIView?
    
    var imageView: UIImageView?
    
    var imageViewOriginalFrame: CGRect = .zero
    
    var startPanPoint: CGPoint = .zero
    
    var interactive: Bool = false
    
    var shouldStartTransition: ( (CGPoint) -> Bool )?
    
    var startTransition: ( () -> Void )?
    
    var cancelTransition: ( () -> Void )?
    
    var finishTransition: ( () -> Void )?
    
    init(viewController: PBPhotoPreviewController) {
        super.init()
        self.viewController = viewController
        let dismissPan = UIPanGestureRecognizer(target: self, action: #selector(dismissPanAction(_:)))
        viewController.view.addGestureRecognizer(dismissPan)
    }
    
    @objc func dismissPanAction(_ pan: UIPanGestureRecognizer) {
        let point = pan.location(in: viewController?.view)
        
        if pan.state == .began {
            guard shouldStartTransition?(point) == true else {
                self.interactive = false
                return
            }
            startPanPoint = point
            interactive = true
            startTransition?()
            viewController?.navigationController?.popViewController(animated: true)
        } else if pan.state == .changed {
            guard interactive else {
                return
            }
            let result = panResult(pan)
            imageView?.frame = result.frame
            shadowView?.alpha = pow(result.scale, 2)
            
            update(result.scale)
        } else if pan.state == .cancelled || pan.state == .ended {
            guard interactive else {
                return
            }
            
            let vel = pan.velocity(in: viewController?.view)
            let p = pan.translation(in: viewController?.view)
            let percent: CGFloat = max(0.0, p.y / (viewController?.view.bounds.height ?? UIScreen.main.bounds.height))
            
            let dismiss = vel.y > 300 || (percent > 0.2 && vel.y > -300)
            
            if dismiss {
                finish()
                finishAnimate()
            } else {
                cancel()
                cancelAnimate()
            }
            imageViewOriginalFrame = .zero
            startPanPoint = .zero
            interactive = false
        }
    }
    
    func panResult(_ pan: UIPanGestureRecognizer) -> (frame: CGRect, scale: CGFloat) {
        // 拖动偏移量
        let translation = pan.translation(in: viewController?.view)
        let currentTouch = pan.location(in: viewController?.view)
        
        // 由下拉的偏移值决定缩放比例，越往下偏移，缩得越小。scale值区间[0.3, 1.0]
        let scale = min(1.0, max(0.3, 1 - translation.y / UIScreen.main.bounds.height))
        
        let width = imageViewOriginalFrame.size.width * scale
        let height = imageViewOriginalFrame.size.height * scale
        
        // 计算x和y。保持手指在图片上的相对位置不变。
        let xRate = (startPanPoint.x - imageViewOriginalFrame.origin.x) / imageViewOriginalFrame.size.width
        let currentTouchDeltaX = xRate * width
        let x = currentTouch.x - currentTouchDeltaX
        
        let yRate = (startPanPoint.y - imageViewOriginalFrame.origin.y) / imageViewOriginalFrame.size.height
        let currentTouchDeltaY = yRate * height
        let y = currentTouch.y - currentTouchDeltaY
        
        return (CGRect(x: x.isNaN ? 0 : x, y: y.isNaN ? 0 : y, width: width, height: height), scale)
    }
    
    override func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        self.transitionContext = transitionContext
        startAnimate()
    }
    
    func startAnimate() {
        guard let context = transitionContext else {
            return
        }
        guard let fromVC = context.viewController(forKey: .from) as? PBPhotoPreviewController, let toVC = context.viewController(forKey: .to) as? PBThumbnailViewController else {
            return
        }
        let containerView = context.containerView
        
        containerView.addSubview(toVC.view)
        
        shadowView = UIView(frame: containerView.bounds)
        shadowView?.backgroundColor = UIColor.black
        containerView.addSubview(shadowView!)
        
        let cell = fromVC.collectionView.cellForItem(at: IndexPath(row: fromVC.currentIndex, section: 0)) as! PBPreviewBaseCell
        
        let fromImageViewFrame = cell.animateImageFrame(convertTo: containerView)
        
        imageView = UIImageView(frame: fromImageViewFrame)
        imageView?.contentMode = .scaleAspectFill
        imageView?.clipsToBounds = true
        imageView?.image = cell.currentImage
        containerView.addSubview(imageView!)
        
        imageViewOriginalFrame = imageView!.frame
    }
    
    func finishAnimate() {
        guard let context = transitionContext else {
            return
        }
        guard let fromVC = context.viewController(forKey: .from) as? PBPhotoPreviewController, let toVC = context.viewController(forKey: .to) as? PBThumbnailViewController else {
            return
        }
        
        let fromVCModel = fromVC.arrDataSources[fromVC.currentIndex]
        let toVCVisiableIndexPaths = toVC.collectionView.indexPathsForVisibleItems
        
        var diff = 0
        if toVC.showCameraCell, !PhotoConfiguration.default().sortAscending {
            diff = -1
        }
        var toIndex: Int? = nil
        for indexPath in toVCVisiableIndexPaths {
            let idx = indexPath.row + diff
            if idx >= toVC.arrDataSources.count || idx < 0 {
                continue
            }
            let m = toVC.arrDataSources[idx]
            if m == fromVCModel {
                toIndex = indexPath.row
                break
            }
        }
        
        var toFrame: CGRect? = nil
        
        if let toIdx = toIndex, let toCell = toVC.collectionView.cellForItem(at: IndexPath(row: toIdx, section: 0)) {
            toFrame = toVC.collectionView.convert(toCell.frame, to: context.containerView)
        }
        
        UIView.animate(withDuration: 0.25, animations: {
            if let to = toFrame {
                self.imageView?.frame = to
            } else {
                self.imageView?.alpha = 0
            }
            self.shadowView?.alpha = 0
        }) { (_) in
            self.imageView?.removeFromSuperview()
            self.shadowView?.removeFromSuperview()
            self.imageView = nil
            self.shadowView = nil
            self.finishTransition?()
            context.completeTransition(!context.transitionWasCancelled)
        }
    }
    
    func cancelAnimate() {
        guard let context = transitionContext else {
            return
        }
        
        UIView.animate(withDuration: 0.25, animations: {
            self.imageView?.frame = self.imageViewOriginalFrame
            self.shadowView?.alpha = 1
        }) { (_) in
            self.imageView?.removeFromSuperview()
            self.shadowView?.removeFromSuperview()
            self.cancelTransition?()
            context.completeTransition(!context.transitionWasCancelled)
        }
    }
    
}
