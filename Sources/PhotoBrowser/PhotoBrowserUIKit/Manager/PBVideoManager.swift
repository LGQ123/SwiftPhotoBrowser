//
//  PBVideoManager.swift
//  LGQPhotos
//
//  Created by 刘广庆 on 2021/1/5.
//

import UIKit
import AVFoundation

class PBVideoManager: NSObject {
    
    class func getVideoExportFilePath() -> String {
        let format = PhotoConfiguration.default().videoExportType.format
        return NSTemporaryDirectory().appendingFormat("/%@.%@", UUID().uuidString, format)
    }
    
    class func exportEditVideo(for asset: AVAsset, range: CMTimeRange, completion: @escaping ( (URL?, Error?) -> Void )) {
        let outputUrl = URL(fileURLWithPath: self.getVideoExportFilePath())
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            completion(nil, NSError(domain: "", code: -1000, userInfo: [NSLocalizedDescriptionKey: "video export failed"]))
            return
        }
        exportSession.outputURL = outputUrl
        exportSession.outputFileType = PhotoConfiguration.default().videoExportType.avFileType
        exportSession.timeRange = range
        
        exportSession.exportAsynchronously(completionHandler: {
            let suc = exportSession.status == .completed
            if exportSession.status == .failed {
                print("PBPhotoBrowser: video export failed: \(exportSession.error?.localizedDescription ?? "")")
            }
            DispatchQueue.main.async {
                completion(suc ? outputUrl : nil, exportSession.error)
            }
        })
    }
    
    /// 没有针对不同分辨率视频做处理，仅用于处理相机拍照的视频
    class func mergeVideos(fileUrls: [URL], completion: @escaping ( (URL?, Error?) -> Void )) {
        let mixComposition = AVMutableComposition()
        
        let assets = fileUrls.map { AVURLAsset(url: $0) }
        
        do {
            // video track
            let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            var instructions: [AVMutableVideoCompositionInstruction] = []
            var videoSize = CGSize.zero
            var start: CMTime = .zero
            for asset in assets {
                let videoTracks = asset.tracks(withMediaType: .video)
                if let assetTrack = videoTracks.first, compositionVideoTrack != nil  {
                    try compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: asset.duration), of: assetTrack, at: start)
                    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack!)
                    layerInstruction.setTransform(assetTrack.preferredTransform, at: start)
                    
                    let instruction = AVMutableVideoCompositionInstruction()
                    instruction.timeRange = CMTimeRangeMake(start: start, duration: asset.duration)
                    instruction.layerInstructions = [layerInstruction]
                    instructions.append(instruction)
                    
                    start = CMTimeAdd(start, asset.duration)
                    if videoSize == .zero {
                        videoSize = assetTrack.naturalSize
                        let info = self.orientationFromTransform(assetTrack.preferredTransform)
                        if info.isPortrait {
                            swap(&videoSize.width, &videoSize.height)
                        }
                    }
                }
            }
            
            
            let mainComposition = AVMutableVideoComposition()
            mainComposition.instructions = instructions
            mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
            mainComposition.renderSize = videoSize
            
            // audio track
            let compositionAudioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            start = .zero
            for asset in assets {
                let audioTracks = asset.tracks(withMediaType: .audio)
                if !audioTracks.isEmpty {
                    try compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: asset.duration), of: audioTracks[0], at: start)
                    start = CMTimeAdd(start, asset.duration)
                }
            }
            
            guard let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPreset1280x720) else {
                completion(nil, NSError(domain: "", code: -1000, userInfo: [NSLocalizedDescriptionKey: "video merge failed"]))
                return
            }
            
            let outputUrl = URL(fileURLWithPath: PBVideoManager.getVideoExportFilePath())
            exportSession.outputURL = outputUrl
            exportSession.shouldOptimizeForNetworkUse = true
            exportSession.outputFileType = PhotoConfiguration.default().videoExportType.avFileType
            exportSession.videoComposition = mainComposition
            exportSession.exportAsynchronously(completionHandler: {
                let suc = exportSession.status == .completed
                if exportSession.status == .failed {
                    print("PBPhotoBrowser: video merge failed:  \(exportSession.error?.localizedDescription ?? "")")
                }
                DispatchQueue.main.async {
                    completion(suc ? outputUrl : nil, exportSession.error)
                }
            })
        } catch {
            completion(nil, error)
        }
    }
    
    static func orientationFromTransform(_ transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
        var assetOrientation = UIImage.Orientation.up
        var isPortrait = false
        let tfA = transform.a
        let tfB = transform.b
        let tfC = transform.c
        let tfD = transform.d
        
        if tfA == 0 && tfB == 1.0 && tfC == -1.0 && tfD == 0 {
            assetOrientation = .right
            isPortrait = true
        } else if tfA == 0 && tfB == -1.0 && tfC == 1.0 && tfD == 0 {
            assetOrientation = .left
            isPortrait = true
        } else if tfA == 1.0 && tfB == 0 && tfC == 0 && tfD == 1.0 {
            assetOrientation = .up
        } else if tfA == -1.0 && tfB == 0 && tfC == 0 && tfD == -1.0 {
            assetOrientation = .down
        }
        return (assetOrientation, isPortrait)
    }
    
}
