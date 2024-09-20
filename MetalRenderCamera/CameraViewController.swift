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

    var startButton: UIButton = {
        let button = UIButton()
        button.setTitle("START", for: .normal)
        button.setTitleColor(.white, for: .normal)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupStartButton()
        session = MetalCameraSession(delegate: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session?.stop()
    }

    func setupStartButton() {
        view.addSubview(startButton)
        startButton.center = view.center
        startButton.frame = CGRect(x: 100, y: 100, width: 100, height: 100)
        startButton.addTarget(self, action: #selector(startButtonDidTap), for: .touchUpInside)
    }

    @objc func startButtonDidTap() {
        session?.start()
    }
}

// MARK: - MetalCameraSessionDelegate
extension CameraViewController: MetalCameraSessionDelegate {
    func metalCameraSession(_ session: MetalCameraSession, didReceiveFrameAsTextures textures: [MTLTexture], withTimestamp timestamp: Double) {
        self.texture = textures[0]
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
