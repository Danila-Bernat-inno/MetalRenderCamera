//
//  ViewController.swift
//  MetalShaderCamera
//
//  Created by Alex Staravoitau on 24/04/2016.
//  Copyright © 2016 Old Yellow Bricks. All rights reserved.
//

import UIKit
import Metal

internal final class CameraViewController: MTKViewController {
    var session: MetalCameraSession?

    var displayLink: CADisplayLink?
    var lastTimestamp: CFTimeInterval = 0
    
    var videoDidStart: Bool = false
    var barButtonTitle: String {
        videoDidStart ? "Stop" : "Start"
    }
    lazy var startButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: barButtonTitle, style: .plain, target: self, action: #selector(startButtonDidTap))
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupStartButton()
        
        displayLink = CADisplayLink(target: self, selector: #selector(render))
        if #available(iOS 10.0, *) {
            displayLink?.preferredFramesPerSecond = 60
        } else {
            // Fallback on earlier versions
        }
        displayLink?.add(to: .main, forMode: .defaultRunLoopMode)
        
        session = MetalCameraSession(delegate: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session?.stop()
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    @objc func render() {
            guard let texture = self.texture else { return }
        
        let drawable = metalView.currentDrawable
            // Здесь вы можете выполнить отрисовку текстуры на Metal
            // Например, вызов метода для обновления интерфейса с использованием текстуры
            // render(texture: texture)
            
            // Также можете использовать lastTimestamp для управления временем, если это нужно
    }

    func setupStartButton() {
        navigationItem.rightBarButtonItem = startButton
    }

    @objc func startButtonDidTap() {
        videoDidStart.toggle()
        startButton.title = barButtonTitle
        if videoDidStart {
            session?.start()
        }
    }
}

// MARK: - MetalCameraSessionDelegate
extension CameraViewController: MetalCameraSessionDelegate {
    func metalCameraSession(_ session: MetalCameraSession, didReceiveFrameAsTextures textures: [MTLTexture], withTimestamp timestamp: Double) {
        self.texture = textures[0]
        self.metalView.draw()
        print(">>> ⏰ Received frame at timestamp: \(timestamp) seconds")
    }
    
    func metalCameraSession(_ cameraSession: MetalCameraSession, didUpdateState state: MetalCameraSessionState, error: MetalCameraSessionError?) {
        
        if error == .captureSessionRuntimeError {
            /**
             *  In this app we are going to ignore capture session runtime errors
             */
            cameraSession.start()
        }
        
        DispatchQueue.main.async { 
            self.title = "Metal camera: \(state)"
        }
        
        NSLog("Session changed state to \(state) with error: \(error?.localizedDescription ?? "None").")
    }
}
