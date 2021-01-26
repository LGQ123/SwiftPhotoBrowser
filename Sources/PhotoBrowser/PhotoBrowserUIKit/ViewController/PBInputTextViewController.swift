//
//  PBInputTextViewController.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import UIKit

class PBInputTextViewController: UIViewController {

    static let collectionViewHeight: CGFloat = 50
    
    let image: UIImage?
    
    var text: String
    
    var cancelBtn: UIButton!
    
    var doneBtn: UIButton!
    
    var textView: UITextView!
    
    var collectionView: UICollectionView!
    
    var currentTextColor: UIColor
    
    /// text, textColor, bgColor
    var endInput: ( (String, UIColor, UIColor) -> Void )?
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    init(image: UIImage?, text: String? = nil, textColor: UIColor? = nil, bgColor: UIColor? = nil) {
        self.image = image
        self.text = text ?? ""
        if let _ = textColor {
            currentTextColor = textColor!
        } else {
            if !PhotoConfiguration.default().textStickerTextColors.contains(PhotoConfiguration.default().textStickerDefaultTextColor) {
                currentTextColor = PhotoConfiguration.default().textStickerTextColors.first!
            } else {
                currentTextColor = PhotoConfiguration.default().textStickerDefaultTextColor
            }
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIApplication.keyboardWillShowNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        textView.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        var insets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        if #available(iOS 11.0, *) {
            insets = view.safeAreaInsets
        }
        
        let btnY = insets.top + 20
        let cancelBtnW: CGFloat = 40.0
        cancelBtn.frame = CGRect(x: 15, y: btnY, width: cancelBtnW, height: PBLayout.bottomToolBtnH)
        
        let doneBtnW: CGFloat = 40.0
        doneBtn.frame = CGRect(x: view.bounds.width - 20 - doneBtnW, y: btnY, width: doneBtnW, height: PBLayout.bottomToolBtnH)
        
        textView.frame = CGRect(x: 20, y: cancelBtn.frame.maxY + 20, width: view.bounds.width - 40, height: 150)
        
        if let index = PhotoConfiguration.default().textStickerTextColors.firstIndex(where: { $0 == currentTextColor}) {
            collectionView.scrollToItem(at: IndexPath(row: index, section: 0), at: .centeredHorizontally, animated: false)
        }
    }
    
    func setupUI() {
        view.backgroundColor = .black
        
        let bgImageView = UIImageView(image: image?.blurImage(level: 4))
        bgImageView.frame = view.bounds
        bgImageView.contentMode = .scaleAspectFit
        view.addSubview(bgImageView)
        
        let coverView = UIView(frame: bgImageView.bounds)
        coverView.backgroundColor = .black
        coverView.alpha = 0.4
        bgImageView.addSubview(coverView)
        
        cancelBtn = UIButton(type: .custom)
        cancelBtn.setTitle("取消", for: .normal)
        cancelBtn.titleLabel?.font = PBLayout.bottomToolTitleFont
        cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        view.addSubview(cancelBtn)
        
        doneBtn = UIButton(type: .custom)
        doneBtn.setTitle("完成", for: .normal)
        doneBtn.titleLabel?.font = PBLayout.bottomToolTitleFont
        doneBtn.addTarget(self, action: #selector(doneBtnClick), for: .touchUpInside)
        view.addSubview(doneBtn)
        
        textView = UITextView(frame: .zero)
        textView.keyboardAppearance = .dark
        textView.returnKeyType = .done
        textView.delegate = self
        textView.backgroundColor = .clear
        textView.tintColor = .bottomToolViewBtnNormalBgColor
        textView.textColor = currentTextColor
        textView.text = text
        textView.font = UIFont.boldSystemFont(ofSize: PBTextStickerView.fontSize)
        view.addSubview(textView)
        
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 30, height: 30)
        layout.minimumLineSpacing = 15
        layout.minimumInteritemSpacing = 15
        layout.scrollDirection = .horizontal
        layout.sectionInset = UIEdgeInsets(top: 10, left: 30, bottom: 10, right: 30)
        collectionView = UICollectionView(frame: CGRect(x: 0, y: view.frame.height - PBInputTextViewController.collectionViewHeight, width: view.frame.width, height: PBInputTextViewController.collectionViewHeight), collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        view.addSubview(collectionView)
        
        PBDrawColorCell.register(collectionView)
    }
    
    @objc func cancelBtnClick() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func doneBtnClick() {
        endInput?(textView.text, currentTextColor, .clear)
        dismiss(animated: true, completion: nil)
    }
    
    @objc func keyboardWillShow(_ notify: Notification) {
        let rect = notify.userInfo?[UIApplication.keyboardFrameEndUserInfoKey] as? CGRect
        let keyboardH = rect?.height ?? 366
        let duration: TimeInterval = notify.userInfo?[UIApplication.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        
        UIView.animate(withDuration: max(duration, 0.25)) {
            self.collectionView.frame = CGRect(x: 0, y: self.view.frame.height - keyboardH - PBInputTextViewController.collectionViewHeight, width: self.view.frame.width, height: PBInputTextViewController.collectionViewHeight)
        }
    }
    
}


extension PBInputTextViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return PhotoConfiguration.default().textStickerTextColors.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PBDrawColorCell.identifier(), for: indexPath) as! PBDrawColorCell
        
        let c = PhotoConfiguration.default().textStickerTextColors[indexPath.row]
        cell.color = c
        if c == currentTextColor {
            cell.bgWhiteView.layer.transform = CATransform3DMakeScale(1.2, 1.2, 1)
        } else {
            cell.bgWhiteView.layer.transform = CATransform3DIdentity
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        currentTextColor = PhotoConfiguration.default().textStickerTextColors[indexPath.row]
        textView.textColor = currentTextColor
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        collectionView.reloadData()
    }
    
    
}


extension PBInputTextViewController: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            doneBtnClick()
            return false
        }
        return true
    }
    
}
