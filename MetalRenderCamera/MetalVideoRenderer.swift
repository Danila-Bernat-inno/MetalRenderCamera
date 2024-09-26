import Foundation
import AVFoundation
import Metal

protocol MetalVideoRendererDelegate {
    func videoRenderSession(_ session: MetalVideoRenderer, didReceiveFrameAsTextures textures: [MTLTexture], withTimestamp timestamp: Double)
}

final class MetalVideoRenderer: NSObject {
    var delegate: MetalVideoRendererDelegate?
    
    var displayLink: CADisplayLink?
    var lastTimestamp: CFTimeInterval = 0
    
    var startTime: CFTimeInterval?
    var assetReader: AVAssetReader?
    var videoOutput: AVAssetReaderTrackOutput?
    
    fileprivate var metalDevice = MTLCreateSystemDefaultDevice()
    // Texture cache we will use for converting frame images to textures
    internal var textureCache: CVMetalTextureCache?
    
    fileprivate var captureSessionQueue = DispatchQueue(label: "MetalRenderSessionQueue", attributes: [])
    
    init(delegate: MetalVideoRendererDelegate? = nil) {
        self.delegate = delegate
    }
    
    var currentTimestamp: CMTime = kCMTimeZero
    var currentSampleBuffer: CMSampleBuffer? = nil
    var videoFrameRate: Double = 0.0
    var frameDuration: Double = 0.0
}

extension MetalVideoRenderer {
    func startDisplayLink() {
        configureRendering()
        displayLink = CADisplayLink(target: self, selector: #selector(renderNextFrame))
        if #available(iOS 10.0, *) {
            displayLink?.preferredFramesPerSecond = Int(videoFrameRate)
        } else {
            // Fallback on earlier versions
        }

        assetReader?.startReading()
        displayLink?.add(to: .main, forMode: .commonModes)
        
        if startTime == nil {
            startTime = displayLink?.timestamp
        }
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    
    func configureRendering() {
        guard let videoURL = Bundle.main.url(forResource: "demoVideo", withExtension: "mp4") else {
            print("Video file not found.")
            return
        }
        
        let asset = AVAsset(url: videoURL)
        do {
            let assetReader = try AVAssetReader(asset: asset)
            self.assetReader = assetReader
            try self.initializeTextureCache()
            try self.initializeOutputData()
            
            // Получаем частоту кадров видео
            if let videoTrack = asset.tracks(withMediaType: .video).first {
                self.videoFrameRate = Double(videoTrack.nominalFrameRate)
                self.frameDuration = 1.0 / videoFrameRate
            }
        } catch {
            print("Error initializing rendering: \(error)")
        }
    }
    
    @objc func renderNextFrame() {
        guard self.assetReader?.status == .reading else {
            displayLink?.invalidate()
            displayLink = nil
            print(">>> Video playback completed or failed.")
            return
        }
        
        do {
            guard let videoOutput else { return }
            
            let elapsed = displayLink!.timestamp - startTime!
            
            if currentSampleBuffer == nil {
                // Берем следующий кадр, если предыдущий был обработан
                guard let sampleBuffer = videoOutput.copyNextSampleBuffer() else {
                    print("No available sample buffers")
                    return
                }
                
                currentSampleBuffer = sampleBuffer
                currentTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            }
            
            // Преобразуем CMSampleBuffer в секунды
            let frameTime = CMTimeGetSeconds(currentTimestamp)
            
            // Если пришло время отобразить следующий кадр
            if frameTime <= elapsed {
                // Преобразуем буфер в текстуру и передаем ее делегату для рендеринга
                if let texture = try? texture(sampleBuffer: currentSampleBuffer, textureCache: textureCache) {
                    delegate?.videoRenderSession(self, didReceiveFrameAsTextures: [texture], withTimestamp: frameTime)
                }
                
                // Переходим к следующему кадру
                currentSampleBuffer = nil
            }
            
            // Если кадры закончились
            if assetReader?.status == .completed {
                print(">>> ✅ Video playback completed.")
            } else if assetReader?.status == .failed {
                print(">>> 😢 Video playback failed with error: \(assetReader?.error?.localizedDescription ?? "Unknown error")")
            }
        } catch {
            print("Error in renderNextFrame: \(error)")
        }
    }
}

extension MetalVideoRenderer {
    fileprivate func initializeTextureCache() throws {
#if arch(i386) || arch(x86_64)
        throw MetalCameraSessionError.failedToCreateTextureCache
#else
        guard
            let metalDevice = metalDevice,
            CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &textureCache) == kCVReturnSuccess
        else {
            throw MetalCameraSessionError.failedToCreateTextureCache
        }
#endif
    }
    
    fileprivate func initializeOutputData() throws {
        guard let assetReader else { return }
        do {
            guard let videoTrack = assetReader.asset.tracks(withMediaType: .video).first else {
                print("No video track found in the asset.")
                return
            }
            
            let videoOutputSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]
            
            let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoOutputSettings)
            videoOutput.alwaysCopiesSampleData = false
            guard assetReader.canAdd(videoOutput) else {
                print("Cannot add video output to asset reader.")
                return
            }
            self.videoOutput = videoOutput
            self.assetReader?.add(videoOutput)
        }
    }
    
    private func texture(sampleBuffer: CMSampleBuffer?, textureCache: CVMetalTextureCache?, planeIndex: Int = 0, pixelFormat: MTLPixelFormat = .bgra8Unorm) throws -> MTLTexture {
        guard let sampleBuffer = sampleBuffer else {
            throw MetalCameraSessionError.missingSampleBuffer
        }
        guard let textureCache = textureCache else {
            throw MetalCameraSessionError.failedToCreateTextureCache
        }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw MetalCameraSessionError.failedToGetImageBuffer
        }
        
        let isPlanar = CVPixelBufferIsPlanar(imageBuffer)
        let width = isPlanar ? CVPixelBufferGetWidthOfPlane(imageBuffer, planeIndex) : CVPixelBufferGetWidth(imageBuffer)
        let height = isPlanar ? CVPixelBufferGetHeightOfPlane(imageBuffer, planeIndex) : CVPixelBufferGetHeight(imageBuffer)
        
        var imageTexture: CVMetalTexture?
        
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, imageBuffer, nil, pixelFormat, width, height, planeIndex, &imageTexture)
        
        guard
            let unwrappedImageTexture = imageTexture,
            let texture = CVMetalTextureGetTexture(unwrappedImageTexture),
            result == kCVReturnSuccess
        else {
            throw MetalCameraSessionError.failedToCreateTextureFromImage
        }
        
        return texture
    }
}
