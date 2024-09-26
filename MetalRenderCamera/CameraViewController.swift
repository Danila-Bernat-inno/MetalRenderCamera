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
    var renderSession: MetalVideoRenderer?
    
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
        renderSession = MetalVideoRenderer(delegate: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        renderSession?.stop()
    }
    
    func setupStartButton() {
        navigationItem.rightBarButtonItem = startButton
    }

    @objc func startButtonDidTap() {
        videoDidStart.toggle()
        startButton.title = barButtonTitle
        if videoDidStart {
            renderSession?.startDisplayLink()
        } else {
            renderSession?.stop()
        }
    }
}

// MARK: - MetalVideoRendererDelegate
extension CameraViewController: MetalVideoRendererDelegate {
    func videoRenderSession(_ session: MetalVideoRenderer, didReceiveFrameAsTextures textures: [any MTLTexture], withTimestamp timestamp: Double) {
        self.texture = textures[0]
        print(">>> ⏰ Received frame at timestamp: \(timestamp) seconds")
    }
}
