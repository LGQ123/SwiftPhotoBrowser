//
//  UIColor+photoBrowser.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/10.
//

import Foundation
import UIKit

extension UIColor {
    
    class var navBarColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.navBarColor
    }
    
    /// 导航标题颜色
    class var navTitleColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.navTitleColor
    }
    
    /// 框架样式为 embedAlbumList 时，title view 背景色
    class var navEmbedTitleViewBgColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.navEmbedTitleViewBgColor
    }
    
    /// 预览选择模式下 上方透明背景色
    class var previewBgColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.previewBgColor
    }
    
    /// 预览选择模式下 拍照/相册/取消 的背景颜色
    class var previewBtnBgColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.previewBtnBgColor
    }
    
    /// 预览选择模式下 拍照/相册/取消 的字体颜色
    class var previewBtnTitleColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.previewBtnTitleColor
    }
    
    /// 预览选择模式下 选择照片大于0时，取消按钮title颜色
    class var previewBtnHighlightTitleColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.previewBtnHighlightTitleColor
    }
    
    /// 相册列表界面背景色
    class var albumListBgColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.albumListBgColor
    }
    
    /// 相册列表界面 相册title颜色
    class var albumListTitleColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.albumListTitleColor
    }
    
    /// 相册列表界面 数量label颜色
    class var albumListCountColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.albumListCountColor
    }
    
    /// 分割线颜色
    class var separatorColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.separatorColor
    }
    
    /// 小图界面背景色
    class var thumbnailBgColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.thumbnailBgColor
    }
    
    /// 底部工具条底色
    class var bottomToolViewBgColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.bottomToolViewBgColor
    }
    
    /// 底部工具栏按钮 可交互 状态标题颜色
    class var bottomToolViewBtnNormalTitleColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.bottomToolViewBtnNormalTitleColor
    }
    
    /// 底部工具栏按钮 不可交互 状态标题颜色
    class var bottomToolViewBtnDisableTitleColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.bottomToolViewBtnDisableTitleColor
    }
    
    /// 底部工具栏按钮 可交互 状态背景颜色
    class var bottomToolViewBtnNormalBgColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.bottomToolViewBtnNormalBgColor
    }
    
    /// 底部工具栏按钮 不可交互 状态背景颜色
    class var bottomToolViewBtnDisableBgColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.bottomToolViewBtnDisableBgColor
    }
    
    /// iOS14 limited 权限时候，小图界面下方显示 选择更多图片 标题颜色
    class var selectMorePhotoWhenAuthIsLismitedTitleColor: UIColor {
        return PhotoConfiguration.default().themeColorDeploy.selectMorePhotoWhenAuthIsLismitedTitleColor
    }
    
    /// 自定义相机录制视频时，进度条颜色
    class var cameraRecodeProgressColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.cameraRecodeProgressColor
    }
    
    /// 已选cell遮罩层颜色
    class var selectedMaskColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.selectedMaskColor
    }
    
    /// 已选cell border颜色
    class var selectedBorderColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.selectedBorderColor
    }
    
    /// 不能选择的cell上方遮罩层颜色
    class var invalidMaskColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.invalidMaskColor
    }
    
    /// 选中图片右上角index background color
    class var indexLabelBgColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.indexLabelBgColor
    }
    
    /// 拍照cell 背景颜色
    class var cameraCellBgColor: UIColor {
        PhotoConfiguration.default().themeColorDeploy.cameraCellBgColor
    }
    
}
