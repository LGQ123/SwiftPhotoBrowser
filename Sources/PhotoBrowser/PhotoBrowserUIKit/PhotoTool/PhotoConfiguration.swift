//
//  PhotoConfiguration.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2020/12/30.
//

import Foundation
import UIKit
import Photos

/// 打开方式
public enum PhotoBrowserStyle: Int {
    /// 缩略图 与相册列表 下拉
    case embedAlbumList
    
    ///  缩略图 与相册列表 push.
    case externalAlbumList
}
/// 编辑方式
public enum EditImageTool: Int {
    case draw
    case clip
    case imageSticker
    case textSticker
    case mosaic
    case filter
}

/// 贴纸协议
public protocol PBImageStickerContainerDelegate where Self: UIView {
    
    /// 需要把图片 传进来
    var selectImageBlock: ( (UIImage) -> Void )? { get set }
    
    /// 消失回调
    var hideBlock: ( () -> Void )? { get set }
    
    /// show
    /// - Parameter view: 需要添加的view上
    func show(in view: UIView)
}

/// 裁剪比例
open class PBImageClipRatio: NSObject {
    
    let title: String
    
    let whRatio: CGFloat
    
    @objc public init(title: String, whRatio: CGFloat) {
        self.title = title
        self.whRatio = whRatio
    }
}

extension PBImageClipRatio {
    
    public static let custom = PBImageClipRatio(title: "自定义", whRatio: 0)
    
    public static let wh1x1 = PBImageClipRatio(title: "1 : 1", whRatio: 1)
    
    public static let wh3x4 = PBImageClipRatio(title: "3 : 4", whRatio: 3.0/4.0)
    
    public static let wh4x3 = PBImageClipRatio(title: "4 : 3", whRatio: 4.0/3.0)
    
    public static let wh2x3 = PBImageClipRatio(title: "2 : 3", whRatio: 2.0/3.0)
    
    public static let wh3x2 = PBImageClipRatio(title: "3 : 2", whRatio: 3.0/2.0)
    
    public static let wh9x16 = PBImageClipRatio(title: "9 : 16", whRatio: 9.0/16.0)
    
    public static let wh16x9 = PBImageClipRatio(title: "16 : 9", whRatio: 16.0/9.0)
}


open class PhotoConfiguration: NSObject {
    private static let single = PhotoConfiguration()
    
    open class func `default`() -> PhotoConfiguration {
        return PhotoConfiguration.single
    }
    
    /// 缩略图—>相册列表展示方式 默认 embedAlbumList
    /// 缩略图 与相册列表 下拉 embedAlbumList
    /// 缩略图 与相册列表 push. externalAlbumList
    open var style: PhotoBrowserStyle = .embedAlbumList
    
    
    /// statusBarStyle 默认 lightContent
    open var statusBarStyle: UIStatusBarStyle = .lightContent
    
    /// 排序 默认 true
    open var sortAscending = true
    
    
    private var pri_maxSelectCount = 9
    /// 最多选取 默认9
    open var maxSelectCount: Int {
        set {
            pri_maxSelectCount = max(1, newValue)
        }
        get {
            return pri_maxSelectCount
        }
    }
    
   
    private var pri_maxVideoSelectCount = 0
    /// 最多选取视频 仅在( allowMixSelect = true))时有效 默认0
    open var maxVideoSelectCount: Int {
        set {
            pri_maxVideoSelectCount = newValue
        }
        get {
            if pri_maxVideoSelectCount <= 0 {
                return maxSelectCount
            } else {
                return max(minVideoSelectCount, min(pri_maxVideoSelectCount, maxSelectCount))
            }
        }
    }
    private var pri_minVideoSelectCount = 0
    /// 最少选取视频 仅在( allowMixSelect = true))时有效 默认0
    open var minVideoSelectCount: Int {
        set {
            pri_minVideoSelectCount = newValue
        }
        get {
            return min(maxSelectCount, max(pri_minVideoSelectCount, 0))
        }
    }
    
    /// 同时选照片，视频 默认true
    open var allowMixSelect = true
    
    /// 预览模式打开 最大预览数 默认20
    open var maxPreviewCount = 20
    
    /// 圆角 默认0
    open var cellCornerRadio: CGFloat = 0
    
    /// 是否允许选择照片  默认true
    open var allowSelectImage = true
    
    /// 是否允许选择视频  默认true
    open var allowSelectVideo = true
    
    /// 是否允许选择Gif  默认true
    open var allowSelectGif = true
    
    /// 是否允许选择LivePhoto  默认false
    open var allowSelectLivePhoto = false
    
    private var pri_allowTakePhotoInLibrary = true
    /// 是否允许在相册中拍照 默认true
    open var allowTakePhotoInLibrary: Bool {
        set {
            pri_allowTakePhotoInLibrary = newValue
        }
        get {
            return pri_allowTakePhotoInLibrary && (allowTakePhoto || allowRecordVideo)
        }
    }
    
    private var pri_allowTakePhoto = true
    /// 是否允许拍照 默认true
    open var allowTakePhoto: Bool {
        set {
            pri_allowTakePhoto = newValue
        }
        get {
            return pri_allowTakePhoto && allowSelectImage
        }
    }
    
    private var pri_allowRecordVideo = true
    /// 是否允许拍视频 默认true
    open var allowRecordVideo: Bool {
        set {
            pri_allowRecordVideo = newValue
        }
        get {
            return pri_allowRecordVideo && allowSelectVideo
        }
    }
    
    /// 是否允许编辑图片 默认true
    open var allowEditImage = true
    
    /// 是否允许编辑视频 默认false
    open var allowEditVideo = false
    
    /// 在缩略图界面选择图像/视频后，直接进入编辑界面。  默认false
    open var editAfterSelectThumbnailImage = false
    
    /// 仿微信的时间轴风格 默认true
    /// 仅当allowMixSelect为false, allowEditVideo为true时有效 如果你想在allowMixSelect = true裁剪视频，请使用**editAfterSelectThumbnailImage
    open var cropVideoAfterSelectThumbnail = true
    
    /// 当你点击编辑，裁剪界面(即ClipImageViewController)就会显示出来。默认false
    open var showClipDirectlyIfOnlyHasClipTool = false
    
    /// 编辑后保存到相册  默认true
    open var saveNewImageAfterEdit = true
    
    /// 是否允许滑动选择照片 默认true
    open var allowSlideSelect = true
    
    /// allowSlideSelect = true时  点击底部 顶部会自动滚动 默认true
    open var autoScrollWhenSlideSelectIsActive = true
    
    /// 自动滚动速度 默认600
    open var autoScrollMaxSpeed: CGFloat = 600
    
    /// 预览是否可以滑动选择 默认false
    open var allowDragSelect = false
    
    /// 允许选择原图 默认true
    open var allowSelectOriginal = true
    
    /// 允许进入预览大图界面(即点击缩略图后是否允许进入大图界面) 默认true
    open var allowPreviewPhotos = true
    
    /// 是否显示预览按钮(即缩略图界面左下角的预览按钮)。 默认true
    open var showPreviewButtonInAlbum = true
    
    private var pri_columnCount: Int = 4
    /// 列数 默认4 最大6 最小2
    /// ```
    /// iPhone 横屏: columnCount += 2.
    /// iPad 竖屏: columnCount += 2.
    /// iPad 横屏: columnCount += 4.
    /// ```
    open var columnCount: Int {
        set {
            pri_columnCount = min(6, max(newValue, 2))
        }
        get {
            return pri_columnCount
        }
    }
    
    /// 允许视频编辑最大时间 /seconds 默认10
    open var maxEditVideoTime: Int = 10
    
    /// 允许选择视频最大时间 /seconds 默认120
    open var maxSelectVideoDuration: Int = 120
    
    /// 最小视频选择时间/seconds 默认0
    open var minSelectVideoDuration: Int = 0
    
    private var pri_editImageTools: [EditImageTool] = [.draw, .clip, .imageSticker, .textSticker, .mosaic, .filter]
    /// 编辑图像工具 默认.draw, .clip, .imageSticker, .textSticker, .mosaic, .filter
    open var editImageTools: [EditImageTool] {
        set {
            pri_editImageTools = newValue
        }
        get {
            if pri_editImageTools.isEmpty {
                return [.draw, .clip, .imageSticker, .textSticker, .mosaic, .filter]
            } else {
                return pri_editImageTools
            }
        }
    }
    
    private var pri_editImageDrawColors: [UIColor] = [.white, .black, RGB(241, 79, 79), RGB(243, 170, 78), RGB(80, 169, 56), RGB(30, 183, 243), RGB(139, 105, 234)]
    /// 图像编辑器绘制颜色 默认 .white, .black, RGB(241, 79, 79), RGB(243, 170, 78), RGB(80, 169, 56), RGB(30, 183, 243), RGB(139, 105, 234)
    open var editImageDrawColors: [UIColor] {
        set {
            pri_editImageDrawColors = newValue
        }
        get {
            if pri_editImageDrawColors.isEmpty {
                return [.white, .black, RGB(241, 79, 79), RGB(243, 170, 78), RGB(80, 169, 56), RGB(30, 183, 243), RGB(139, 105, 234)]
            } else {
                return pri_editImageDrawColors
            }
        }
    }
    
    /// 默认绘制颜色 默认RGB(241, 79, 79)
    open var editImageDefaultDrawColor = RGB(241, 79, 79)
    private var pri_editImageClipRatios: [PBImageClipRatio] = [.custom]
    /// 图像编辑器的编辑比例 默认custom
    open var editImageClipRatios: [PBImageClipRatio] {
        set {
            pri_editImageClipRatios = newValue
        }
        get {
            if pri_editImageClipRatios.isEmpty {
                return [.custom]
            } else {
                return pri_editImageClipRatios
            }
        }
    }
    
    private var pri_textStickerTextColors: [UIColor] = [.white, .black, RGB(241, 79, 79), RGB(243, 170, 78), RGB(80, 169, 56), RGB(30, 183, 243), RGB(139, 105, 234)]
    /// 文字贴纸颜色 默认.white, .black, RGB(241, 79, 79), RGB(243, 170, 78), RGB(80, 169, 56), RGB(30, 183, 243), RGB(139, 105, 234)
    open var textStickerTextColors: [UIColor] {
        set {
            pri_textStickerTextColors = newValue
        }
        get {
            if pri_textStickerTextColors.isEmpty {
                return [.white, .black, RGB(241, 79, 79), RGB(243, 170, 78), RGB(80, 169, 56), RGB(30, 183, 243), RGB(139, 105, 234)]
            } else {
                return pri_textStickerTextColors
            }
        }
    }
    
    /// 默认文本贴纸颜色 默认white
    open var textStickerDefaultTextColor = UIColor.white
    
    /// 默认文本贴纸大小 默认30
    open var textStickerFontSize: CGFloat = 30
    
    private var pri_filters: [PBFilter] = PBFilter.all
    /// 图像编辑器 默认all
    open var filters: [PBFilter] {
        set {
            pri_filters = newValue
        }
        get {
            if pri_filters.isEmpty {
                return PBFilter.all
            } else {
                return pri_filters
            }
        }
    }
    
    /// 图片贴纸 view
    open var imageStickerContainerView: (UIView & PBImageStickerContainerDelegate)? = nil
    
    /// 显示相机捕捉到的图像显示在相册内的相机按钮上。
    open var showCaptureImageOnTakePhotoBtn = false
    
    /// 在单选模式下，是否显示选择按钮。
    open var showSelectBtnWhenSingleSelect = false
    
    /// 在选定的照片上叠加一个蒙版层。
    open var showSelectedMask = true
    
    /// 在选定的照片单元格上显示边框。
    open var showSelectedBorder = false
    
    /// 在不能被选中的单元格上覆盖一个蒙版层
    open var showInvalidMask = true
    
    /// 显示所选照片的索引。
    open var showSelectedIndex = true
    
    /// 在预览大照片界面的底部显示所选的照片。
    open var showSelectedPhotoPreview = true
    
    /// 允许框架在回调时取回照片  这个也可以通过PBPhotoPreviewSheet的回调来实现
    open var shouldAnialysisAsset = true
    
    /// Timeout
    open var timeout: TimeInterval = 20
    
    /// 是否使用自定义相机
    open var useCustomCamera = true
    
    private var pri_minRecordDuration: Int = 0
    /// 最少录制时间
    open var minRecordDuration: Int {
        set {
            pri_minRecordDuration = max(0, newValue)
        }
        get {
            return pri_minRecordDuration
        }
    }
    
    private var pri_maxRecordDuration: Int = 10
    /// 最大录制时间
    open var maxRecordDuration: Int {
        set {
            pri_maxRecordDuration = max(1, newValue)
        }
        get {
            return pri_maxRecordDuration
        }
    }
    
    /// 视频分辨率
    open var sessionPreset: PBCustomCamera.CaptureSessionPreset = .hd1280x720
    
    /// 视频导出格式
    open var videoExportType: PBCustomCamera.VideoExportType = .mov
    
    /// flahs模式
    open var cameraFlashMode: PBCustomCamera.CameraFlashMode = .off
    
    /// Hud style.
    open var hudStyle: PBProgressHUD.HUDStyle = .lightBlur
    
    /// Navigation bar blur effect.
    open var navViewBlurEffect: UIBlurEffect? = UIBlurEffect(style: .dark)
    
    /// Bottom too bar blur effect.
    open var bottomToolViewBlurEffect: UIBlurEffect? = UIBlurEffect(style: .dark)
    
    /// 主题颜色
    open var themeColorDeploy: PBPhotoThemeColorDeploy = .default()
    
    
    /// 模块是否允许选择
    open var canSelectAsset: ( (PHAsset) -> Bool )?
    
    
    /// iOS14 有限照片模式下是否显示 +
    open var showAddPhotoButton: Bool = true
    
    /// iOS14 有限模式 是否显示 跳转设置
    open var showEnterSettingFooter = true
}

/// Color
open class PBPhotoThemeColorDeploy: NSObject {
    
    
    open class func `default`() -> PBPhotoThemeColorDeploy {
        return PBPhotoThemeColorDeploy()
    }
    
    /// 预览选择模式 背景颜色
    open var previewBgColor = UIColor.black.withAlphaComponent(0.1)
    
    /// 预览选择模式，背景颜色为“相机”，“相册”，“取消”按钮。
    open var previewBtnBgColor = UIColor.white
    
    /// 预览选择模式，文本颜色为“相机”，“相册”，“取消”按钮。
    open var previewBtnTitleColor = UIColor.black
    
    /// 预览选择模式，当选择量大于0时取消按钮标题颜色。
    open var previewBtnHighlightTitleColor = RGB(80, 169, 56)
    
    /// 导航条颜色
    open var navBarColor = RGB(160, 160, 160).withAlphaComponent(0.65)
    
    /// 导航条title颜色
    open var navTitleColor = UIColor.white
    
    /// 当embedAlbumList时，标题视图的背景颜色。
    open var navEmbedTitleViewBgColor = RGB(80, 80, 80)
    
    /// 相册列表背景颜色
    open var albumListBgColor = RGB(45, 45, 45)
    
    /// 相册列表cell title背景颜色
    open var albumListTitleColor = UIColor.white
    
    /// 相册列表界面 数量label颜色
    open var albumListCountColor = RGB(180, 180, 180)
    
    /// 分割线颜色
    open var separatorColor = RGB(60, 60, 60)
    
    /// 缩略图界面的背景颜色
    open var thumbnailBgColor = RGB(50, 50, 50)
    
    /// 底部工具视图的背景颜色。
    open var bottomToolViewBgColor = RGB(35, 35, 35).withAlphaComponent(0.3)
    
    /// 底部工具视图按钮的正常状态标题颜色。
    open var bottomToolViewBtnNormalTitleColor = UIColor.white
    
    /// 底部工具视图按钮的禁用状态标题颜色。
    open var bottomToolViewBtnDisableTitleColor = RGB(168, 168, 168)
    
    /// 底部工具视图按钮的正常状态背景色。
    open var bottomToolViewBtnNormalBgColor = RGB(80, 169, 56)
    
    /// 底部工具视图按钮的禁用状态背景色。
    open var bottomToolViewBtnDisableBgColor = RGB(50, 50, 50)
    
    /// iOS14有限模式  缩略图界面底部有一种用于选择更多照片的颜色。
    open var selectMorePhotoWhenAuthIsLismitedTitleColor = UIColor.white
    
    /// 相机的进度颜色。
    open var cameraRecodeProgressColor = RGB(80, 169, 56)
    
    /// 选中的蒙版颜色
    open var selectedMaskColor = UIColor.black.withAlphaComponent(0.2)
    
    /// 选中的边框颜色。
    open var selectedBorderColor = RGB(80, 169, 56)
    
    /// 不能被选择的蒙版颜色.
    open var invalidMaskColor = UIColor.white.withAlphaComponent(0.5)
    
    /// 选中索引标签的背景颜色。
    open var indexLabelBgColor = RGB(80, 169, 56)
    
    /// 相机背景
    open var cameraCellBgColor = UIColor(white: 0.3, alpha: 1)
    
}
