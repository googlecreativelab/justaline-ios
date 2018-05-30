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

import ARKit
import FirebaseAnalytics

extension ViewController: ARSCNViewDelegate, ARSessionDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        node.simdTransform = anchor.transform
        
        if let stroke = getStroke(for: anchor) {
            print ("did add: \(node.position)")
            print ("stroke first position: \(stroke.points[0])")
            stroke.node = node

            DispatchQueue.main.async {
                self.updateGeometry(stroke)
            }
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let stroke = getStroke(for: anchor) {
            print("Renderer did update node transform: \(node.transform) and anchorTranform: \(anchor.transform)")
            stroke.node = node
            if ((stateManager?.state == .HOST_CONNECTING || stateManager?.state == .SYNCED || stateManager?.state == .FINISHED)
                        && strokes.contains(stroke)) {
                
                pairingManager?.updateStroke(stroke)

                DispatchQueue.main.async {
                    self.updateGeometry(stroke)
                }
            }
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        if let stroke = getStroke(for: node) {
            
            if (strokes.contains(stroke)) {
                if let index = strokes.index(of: stroke) {
                    strokes.remove(at: index)
                }
            } else {
                let matches = partnerStrokes.filter { (key, partnerStroke) in
                    partnerStroke == stroke
                }
                if let key = matches.first?.key {
                    partnerStrokes[key] = nil
                }
            }
            stroke.cleanup()
            
            print("Stroke removed.  Total strokes=\(strokes.count)")

            DispatchQueue.main.async {
                self.uiViewController?.undoButton.isHidden = self.shouldHideUndoButton()
                self.uiViewController?.clearAllButton.isHidden = self.shouldHideTrashButton()
                if (self.mode == .DRAW && self.strokes.count == 0) { self.uiViewController?.showDrawingPrompt() }
                UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil)
            }
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if (touchPoint != .zero) {
            if let stroke = strokes.last {
                DispatchQueue.main.async {
                    self.updateLine(for: stroke)
                }
            }
        }
        for (_, stroke) in partnerStrokes {
            let needsUpdate = stroke.updateAnimatedStroke()
            if needsUpdate {
                DispatchQueue.main.async {
                    self.updateGeometry(stroke)
                }
            }
        }

    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .notAvailable:
            print("No tracking")
            if shouldShowTrackingIndicator() {
                enterTrackingState()
            }

        case .limited(let reason):
            print("Limited tracking")
            if shouldShowTrackingIndicator() {
                if reason == .relocalizing {
                    NSLog("Relocalizing...")
                    
                    // while relocalizing after interruption, only attempt for 5 seconds, then reset, and only when not paired
                    if strokes.count > 0 && resumeFromInterruptionTimer == nil && pairingManager?.isPairingOrPaired == false {
                        resumeFromInterruptionTimer = Timer(timeInterval: 5, repeats: false, block: { (timer) in
                            NSLog("Resetting ARSession because relocalizing took too long")
                            DispatchQueue.main.async {
                                self.resumeFromInterruptionTimer?.invalidate()
                                self.resumeFromInterruptionTimer = nil
                                self.configureARSession(runOptions: [ARSession.RunOptions.resetTracking])
                            }
                        })
                        RunLoop.main.add(resumeFromInterruptionTimer!, forMode: RunLoopMode.defaultRunLoopMode)
                    } else { // if strokes.count == 0 {
                        // only do the timer if user has drawn strokes
                        self.configureARSession(runOptions: [.resetTracking, .removeExistingAnchors])
                    }
                }
                enterTrackingState()
            }
            
        case .normal:
            if (!hasInitialTracking) {
                hasInitialTracking = true
                Analytics.setUserProperty(AnalyticsKey.val(.value_true), forName: AnalyticsKey.val(.tracking_has_established))
            }
            if !shouldShowTrackingIndicator() {
                exitTrackingState()
            }
            if let pairingMgr = pairingManager, pairingMgr.isPairingOrPaired, shouldRetryAnchorResolve {
                pairingManager?.retryResolvingAnchor()
                pairingManager?.stopObservingLines()
            }
        }
    }
    
    /// Hold onto tracking mode exiting (unless it is already .TRACKING) enter .TRACKING and start animation
    func enterTrackingState() {
        print("ViewController: enterTrackingState")
        resetTouches()
        
        trackingMessage = .looking

        if let pairingMgr = pairingManager, pairingMgr.isPairingOrPaired == true, (mode == .DRAW || (mode == .TRACKING && modeBeforeTracking == .DRAW)) {
            trackingMessage = .anchorLost
        } else if trackingMessageTimer == nil {
            trackingMessage = .looking

            trackingMessageTimer = Timer(timeInterval: 3, repeats: false, block: { (timer) in
                self.trackingMessage = .lookingEscalated
                
                // need to set mode again to update tracking message
                self.mode = .TRACKING

                self.trackingMessageTimer?.invalidate()
                self.trackingMessageTimer = nil
            })
            RunLoop.main.add(trackingMessageTimer!, forMode: RunLoopMode.defaultRunLoopMode)
        }
        
        if mode != .TRACKING {
            print("Entering tracking with mode: \(mode)")
            modeBeforeTracking = mode
        }
        mode = .TRACKING
    }
    
    /// Clean up when returning to normal tracking
    func exitTrackingState() {
        print("ViewController: exitTrackingState")
        
        if resumeFromInterruptionTimer != nil { print("Relocalizing successful.") }
        
        trackingMessageTimer?.invalidate()
        trackingMessageTimer = nil

        resumeFromInterruptionTimer?.invalidate()
        resumeFromInterruptionTimer = nil
        
        // Restore previous mode set in enterTrackingState and updated in mode changes
        if let previousMode = modeBeforeTracking {
            mode = previousMode
            modeBeforeTracking = nil
        }
    }
    
    /// In pair mode, only show tracking indicator in certain states
    func shouldShowTrackingIndicator()->Bool {
        var shouldShow = false
        if let trackingState = sceneView.session.currentFrame?.camera.trackingState {
            switch trackingState {
            case .limited:
                if let pairState = (UIApplication.shared.delegate as! AppDelegate).pairingState, (mode == .PAIR || modeBeforeTracking == .PAIR) {
                    shouldShow = StateManager.shouldShowTracking(for:pairState)
                } else {
                    shouldShow = true
                }
            default:
                break
            }
        }
        // when rejoining after background, continue to show tracking message even when no longer tracking until cloud anchor is re-resolved
        if shouldRetryAnchorResolve { shouldShow = true }

        return shouldShow
    }
    
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let arError = error as? ARError else { return }
        
        let nsError = error as NSError
        var sessionErrorMsg = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
        if let recoveryOptions = nsError.localizedRecoveryOptions {
            for option in recoveryOptions {
                sessionErrorMsg.append("\(option).")
            }
        }
        
        let isRecoverable = (arError.code == .worldTrackingFailed)
        if isRecoverable {
            sessionErrorMsg += "\nYou can try resetting the session or quit the application."
        } else {
            sessionErrorMsg += "\nThis is an unrecoverable error that requires to quit the application."
        }
        
        if (arError.code == .cameraUnauthorized) {
            Analytics.logEvent(AnalyticsKey.val(.camera_permission_denied), parameters: nil)
            let alertController = UIAlertController(title: NSLocalizedString("error_resuming_session", comment: "Sorry something went wrong"), message: NSLocalizedString("error_camera_not_available", comment: "Sorry, something went wrong. Please try again."), preferredStyle: .alert)
            let okAction = UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default) { (action) in
                alertController.dismiss(animated: true, completion: nil)
            }
            alertController.addAction(okAction)
            uiViewController?.present(alertController, animated: true, completion: nil)
        }
        
//        displayErrorMessage(title: "We're sorry!", message: sessionErrorMsg, allowRestart: isRecoverable)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        if let _ = pairingManager?.garAnchor {
            shouldRetryAnchorResolve = true
//            sceneView.session.setWorldOrigin(relativeTransform: float4x4(SCNMatrix4Identity))
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        NSLog("Session resuming after interruption")
        
        #if JOIN_GLOBAL_ROOM
        if pairingManager?.isPairingOrPaired == true {
            pairingManager?.resumeSession(fromDate: Date())
        }
        #else
        if let backgroundDate = UserDefaults.standard.object(forKey: DefaultsKeys.backgroundDate.rawValue) as? Date {
            if backgroundDate.addingTimeInterval(180).compare(Date()) == ComparisonResult.orderedAscending {
                // if it has been too long since last session, reset tracking and remove anchors
                configureARSession(runOptions: [.resetTracking, .removeExistingAnchors])
                self.pairCancelled()
            } else {
                if pairingManager?.isPairingOrPaired == true {
                    if let _ = pairingManager?.garAnchor {
//                        sceneView.session.setWorldOrigin(relativeTransform: garAnchor.transform)
                    }

                    pairingManager?.resumeSession(fromDate: backgroundDate)
                }
            }
        }
        #endif
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        do {
            try pairingManager?.gSession?.update(frame)
        } catch let error as NSError{
            print("ViewController:session didUpdate: There was a problem updating the gSession frame: \(error)")
        }
    }

}
