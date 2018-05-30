// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import SceneKit
import CoreMedia
import AVFoundation
import ReplayKit
import FirebaseAnalytics

extension ViewController: InterfaceViewControllerDelegate {
    
    func stateViewLoaded(_ stateManager: StateManager) {
        self.stateManager = stateManager
        stateManager.delegate = self
    }
    

    // MARK: - Handle Touch
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touchInView = touches.first?.location(in: sceneView), mode == .DRAW else {
            return
        }
        
        // hold onto touch location for projection
        touchPoint = touchInView
        
        // begin a new stroke
        let stroke = Stroke()
        print("Touch")
        if let anchor = makeAnchor(at:touchPoint) {
            stroke.anchor = anchor
            stroke.points.append(SCNVector3Zero)
            stroke.touchStart = touchPoint
            stroke.lineWidth = strokeSize.rawValue

            strokes.append(stroke)
            self.uiViewController?.undoButton.isHidden = shouldHideUndoButton()
            self.uiViewController?.clearAllButton.isHidden = shouldHideTrashButton()
            sceneView.session.add(anchor: anchor)
            
            Analytics.setUserProperty(AnalyticsKey.val(.value_true), forName: AnalyticsKey.val(.user_has_drawn))
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touchInView = touches.first?.location(in: sceneView), mode == .DRAW, touchPoint != .zero else {
            return
        }
        
        // hold onto touch location for projection
        touchPoint = touchInView
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchPoint = CGPoint.zero
        strokes.last?.resetMemory()
        
        // for some reason putting this in the touchesBegan does not trigger
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil)
        
    }
    
    override var shouldAutorotate: Bool {
        get {
            if let recorder = screenRecorder, recorder.isRecording { return false }
            return true
        }
    }

    
    // MARK: - UI Methods
    
    func recordTapped(sender: UIButton?) {
        resetTouches()
        
        if screenRecorder?.isRecording == true {
            // Reset record button accessibility label to original value
            uiViewController?.configureAccessibility()
            
            stopRecording()
        } else {
            sender?.accessibilityLabel = NSLocalizedString("content_description_record_stop", comment: "Stop Recording")
            startRecording()
            
            Analytics.logEvent(AnalyticsKey.val(.record), parameters: nil)
        }
    }

    func startRecording() {
        screenRecorder?.startRecording(handler: { (error) in
            guard error == nil else {
                return
            }
            self.uiViewController?.recordingWillStart()
            
        })
    }
    
    func stopRecording() {
        uiViewController?.progressCircle.stop()
        screenRecorder?.stopRecording(handler: { (previewViewController, error) in
            DispatchQueue.main.async {
                guard error == nil, let preview = previewViewController else {
                    return
                }
                self.uiViewController?.recordingHasEnded()
                previewViewController?.previewControllerDelegate = self
                previewViewController?.modalPresentationStyle = .overFullScreen

                self.present(preview, animated: true, completion:nil)
                self.uiWindow?.isHidden = true
            }
        })
    }
    
    /// Remove anchor for last stroke.
    /// Stroke cleanup in renderer(renderer:didRemove:for:) delegate call
    func undoLastStroke(sender: UIButton?) {
        resetTouches()
        
        if let lastStroke = strokes.last {
            pairingManager?.removeStroke(lastStroke)

            if let anchor = lastStroke.anchor {
                sceneView.session.remove(anchor: anchor)
            }
            
            Analytics.setUserProperty(AnalyticsKey.val(.value_true), forName: AnalyticsKey.val(.user_tapped_undo))
        }
    }

    /// Loops through strokes removing anchor for each stroke.
    /// Stroke cleanup in renderer(renderer:didRemove:for:) delegate call
    func clearStrokesTapped(sender: UIButton?) {
        resetTouches()
        
        var clearMessageKey = "clear_confirmation_message"
        var clearTitleKey = "clear_confirmation_title"
        if partnerStrokes.count > 0 {
            clearMessageKey = "clear_confirmation_message_paired"
            clearTitleKey = "clear_confirmation_title_paired"
        }
        
        let alertController = UIAlertController(
            title: NSLocalizedString(clearTitleKey, comment: "Clear Drawing"),
            message: NSLocalizedString(clearMessageKey, comment: "Clear your drawing?"),
            preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel"), style: .cancel) { (cancelAction) in
            alertController.dismiss(animated: true, completion: nil)
        }
        
        let okAction = UIAlertAction(title: NSLocalizedString("clear", comment: "Clear"), style: .destructive) { (okAction) in
            alertController.dismiss(animated: true, completion: nil)
            self.clearAllStrokes()
            
            if self.mode == .DRAW {
                self.uiViewController?.showDrawingPrompt()
            }
            
            Analytics.setUserProperty(AnalyticsKey.val(.value_true), forName: AnalyticsKey.val(.user_tapped_clear))
        }
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        self.uiViewController?.present(alertController, animated: true, completion: nil)
    }
    
    func clearAllStrokes() {
        for stroke in self.strokes {
            if let anchor = stroke.anchor {
                self.sceneView.session.remove(anchor: anchor)
            }
        }
        
        for (_, partnerStroke) in self.partnerStrokes {
            if let anchor = partnerStroke.anchor {
                self.sceneView.session.remove(anchor: anchor)
            }
        }
        
        self.pairingManager?.clearAllStrokes()
    }
    
    func strokeSizeChanged(_ radius: Radius) {
        strokeSize = radius
    }
    
    func joinButtonTapped(sender: UIButton?) {
        if pairingManager?.isPairingOrPaired == true {
            // TODO: This text is incorrect compared to Android
            let alertController = UIAlertController(title: NSLocalizedString("pair_disconnect_title", comment: "Disconnect"), message: NSLocalizedString("pair_disconnect", comment: "Are you sure you want to disconnect?"), preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: NSLocalizedString("cancel", comment:"Cancel"), style: .cancel) { (cancelAction) in
                alertController.dismiss(animated: true, completion: nil)
            }

            let okAction = UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .destructive) { (okAction) in
                alertController.dismiss(animated: true, completion: nil)
                self.pairCancelled()
                self.configureARSession(runOptions: [.resetTracking, .removeExistingAnchors])
                
                Analytics.logEvent(AnalyticsKey.val(.tapped_disconnect_paired_session), parameters: nil)
            }
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            self.uiViewController?.present(alertController, animated: true, completion: nil)
        } else {
            pairingManager?.beginPairing()

            mode = .PAIR
            Analytics.logEvent(AnalyticsKey.val(.tapped_start_pair), parameters: nil)
            Analytics.setUserProperty(AnalyticsKey.val(.value_true), forName: AnalyticsKey.val(.user_tapped_pair))
        }
    }
    
    func shouldPresentPairingChooser()->Bool {
        if let isPaired = pairingManager?.isPairingOrPaired {
            return !isPaired
        }
        return false
    }
    
    func beginGlobalSession(_ withPairing: Bool) {
        pairingManager?.beginGlobalSession(withPairing)
        mode = .PAIR
    }
    
    func shouldHideTrashButton()->Bool {
        if strokes.count > 0 || partnerStrokes.count > 0 {
            return false
        }
        return true
    }
    
    func shouldHideUndoButton()->Bool {
        if (strokes.count > 0) {
            return false
        }
        return true
    }
    
    func resetTouches() {
        touchPoint = .zero
    }

}
