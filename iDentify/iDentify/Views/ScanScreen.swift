/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Main view controller for the AR experience.
 */

import UIKit
import Metal
import MetalKit
import ARKit
import SwiftUI

final class ViewController: UIViewController, ARSessionDelegate {
    private let isUIEnabled = true
    private let recordButton = UIButton(frame: CGRect (x: 0, y: 0, width: 200, height: 100))
    private let clearButton = UIButton()
    private let hiddenView = UIButton()
    private let toolBar = UIToolbar()
    private let export = UIButton()
    private let oldScans = UIButton()
    private let info = UIButton()
    
    private var isRecording = false
    
    private var taskNum = 0;
    private var completedTaskNum = 0;
    
    private let session = ARSession()
    private var renderer: Renderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
        session.delegate = self
        
        // Set the view to use the default device
        if let view = view as? MTKView {
            view.device = device
            
            view.backgroundColor = UIColor.clear
            // we need this to enable depth test
            view.depthStencilPixelFormat = .depth32Float
            view.contentScaleFactor = 1
            view.delegate = self
            
            // Configure the renderer to draw to the view
            renderer = Renderer(session: session, metalDevice: device, renderDestination: view)
            renderer.drawRectResized(size: view.bounds.size)
            renderer.delegate = self
        }
        // UIButton
        recordButton.layer.cornerRadius = 100
        recordButton.layer.position.x = view.frame.size.width / 2
        recordButton.layer.position.y = view.frame.size.height - 133
        recordButton.setTitle("START", for: .normal)
        recordButton.backgroundColor = .systemBlue
        recordButton.addTarget(self, action: #selector(onButtonClick), for: .touchUpInside)
        
        //UIToolBar
        toolBar.backgroundColor = .black
        toolBar.barTintColor = .black
        toolBar.frame.size.width = view.frame.size.width
        toolBar.frame.size.height = view.frame.size.height - 1200
        toolBar.layer.position.x = view.frame.size.width / 2
        toolBar.layer.position.y = view.frame.size.height - 50
        
        clearButton.layer.cornerRadius = 100
        clearButton.frame.size.width = 100
        clearButton.frame.size.height = 100
        clearButton.setBackgroundImage(.init(systemName: "trash.circle.fill"), for: .normal)
        clearButton.tintColor = .red
        clearButton.addTarget(self, action: #selector(viewValueChanged), for: .touchUpInside)
        clearButton.layer.position.x = view.frame.size.width / 8
        clearButton.layer.position.y = view.frame.size.height - 75
        
        hiddenView.layer.cornerRadius = 100
        hiddenView.frame.size.width = 125
        hiddenView.frame.size.height = 100
        hiddenView.setBackgroundImage(.init(systemName: "eye"), for: .normal)
        hiddenView.tintColor = .red
        hiddenView.addTarget(self, action: #selector(viewValueChanged), for: .touchUpInside)
        hiddenView.layer.position.x = view.frame.size.width / 3.5
        hiddenView.layer.position.y = view.frame.size.height - 75
        
        export.layer.cornerRadius = 25
        export.frame.size.width = view.frame.size.width / 3.5
        export.frame.size.height = 100
        export.backgroundColor = .green
        export.setTitle("SAVE & SEARCH", for: .normal)
        export.layer.position.x = view.frame.size.width / 1.25
        export.layer.position.y = view.frame.size.height - 70
        export.addTarget(self, action: #selector(viewValueChanged), for: .touchUpInside)
        
        oldScans.layer.cornerRadius = 100
        oldScans.frame.size.width = 50
        oldScans.frame.size.height = 50
        oldScans.setBackgroundImage(.init(systemName: "shippingbox.circle.fill"), for: .normal)
        oldScans.tintColor = .white
        oldScans.layer.position.x = view.frame.midX
        oldScans.layer.position.y = view.frame.height - 50
        oldScans.addTarget(self, action: #selector(viewValueChanged), for: .touchUpInside)
        
        info.layer.cornerRadius = 100
        info.frame.size.width = 50
        info.frame.size.height = 50
        info.setBackgroundImage(.init(systemName: "info.circle.fill"), for: .normal)
        info.tintColor = .white
        info.layer.position.x = view.frame.minX + 50
        info.layer.position.y = view.frame.minY + 50
        info.addTarget(self, action: #selector(viewValueChanged), for: .touchUpInside)
        
        
        view.addSubview(toolBar)
        view.addSubview(recordButton)
        view.addSubview(clearButton)
        view.addSubview(hiddenView)
        view.addSubview(export)
        view.addSubview(oldScans)
        view.addSubview(info)
    }
    @objc func viewValueChanged(view: UIView) {
        switch view {
        case clearButton:
            renderer.clearParticles()
        case hiddenView:
            renderer.rgbOn = !renderer.rgbOn
            let iconName = renderer.rgbOn ? "eye": "eye.slash"
            hiddenView.setBackgroundImage(.init(systemName: iconName), for: .normal)
        case export:
            renderer.savePointCloud()
            performSegue(withIdentifier: "exportscreen", sender: view)
        case oldScans:
            performSegue(withIdentifier: "oldscreen", sender: view)
        case info:
            performSegue(withIdentifier: "infosegue", sender: view)
        default: break
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a world-tracking configuration, and
        // enable the scene depth frame-semantic.
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        
        // Run the view's session
        session.run(configuration)
        
        
        // The screen shouldn't dim during AR experiences.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        print("memory warning!!!")
        memoryAlert()
        updateIsRecording(_isRecording: false)
    }
    
    private func memoryAlert() {
        let alert = UIAlertController(title: "Low Memory Warning", message: "The recording has been paused. Do not quit the app until all files have been saved.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
            NSLog("The \"OK\" alert occured.")
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc
    private func onButtonClick(_ sender: UIButton) {
        if (sender != recordButton) {
            return
        }
        updateIsRecording(_isRecording: !isRecording)
    }
    
    
    private func updateIsRecording(_isRecording: Bool) {
        isRecording = _isRecording
        if (isRecording){
            recordButton.setTitle("PAUSE", for: .normal)
            recordButton.backgroundColor = .systemRed
            renderer.currentFolder = getTimeStr()
            createDirectory(folder: renderer.currentFolder + "/data")
        } else {
            recordButton.setTitle("START", for: .normal)
            recordButton.backgroundColor = .systemBlue
        }
        renderer.isRecording = isRecording
    }
    
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // Hide the status bar to maximize immersion in AR experiences.
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                if let configuration = self.session.configuration {
                    self.session.run(configuration, options: .resetSceneReconstruction)
                }
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

// MARK: - MTKViewDelegate

extension ViewController: MTKViewDelegate {
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
    }
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        renderer.draw()
    }
}

// update textlabel on tasks start/finish
extension ViewController: TaskDelegate {
    func didStartTask() {
        self.taskNum += 1
    }
    
    func didFinishTask() {
        self.completedTaskNum += 1
    }
}

// MARK: - RenderDestinationProvider

protocol RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}

extension MTKView: RenderDestinationProvider {
    
}

