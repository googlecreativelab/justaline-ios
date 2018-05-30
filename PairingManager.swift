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

import Foundation
import Reachability
import FirebaseAnalytics

protocol PairingManagerDelegate {
    func localStrokeRemoved(_ stroke: Stroke)
    func partnerStrokeUpdated(_ stroke: Stroke, id key:String)
    func partnerStrokeRemoved(id key:String)
    func cloudAnchorResolved(_ anchor: GARAnchor)
    func partnerJoined(isHost: Bool)
    func partnerLost()
    func createAnchor()
    func anchorWasReset()
    func offlineDetected()
    func isTracking()->Bool
}

class PairingManager: NSObject {
    
    // MARK: Properties
    /// Delegate property for ViewController
    var delegate: PairingManagerDelegate?

    /// RoomManager handles Firebase interactions
    let roomManager: RoomManager

    /// GNSMessageManager handles all Nearby interactions
    let messageManager: GNSMessageManager

    /// Retains subscription until ready to end Nearby
    var messageSubscription: GNSSubscription?
    
    var messagePublication: GNSPublication?
    
    /// GoogleAR Session
    var gSession: GARSession?
    
    @objc var garAnchor: GARAnchor?
    
    var reachability = Reachability.forInternetConnection()
    
    var anchorObserver: NSKeyValueObservation?
    
    var isPairingOrPaired = false
    
    var readyToSetAnchor = false
    
    var partnerReadyToSetAnchor = false
    
    var firebaseKey: String = ""
    
    var pairingTimeout: Timer?
    
    var discoveryTimeout: Timer?


    /// HostedManager handles all Copresence interactions
//    let hostedManager: Any

    // MARK: Methods
    override init() {
        roomManager = RoomManager()
        
        var myDict: NSDictionary?
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
            myDict = NSDictionary(contentsOfFile: path)
        }
        
        if let dict = myDict, let key = dict["API_KEY"] as? String {
            firebaseKey = key
        }
        
        messageManager = GNSMessageManager(apiKey:firebaseKey, paramsBlock: { (params: GNSMessageManagerParams?) in
            guard let params = params else {
                return
            }
            params.microphonePermissionErrorHandler = { (hasError: Bool) in
                // Update the UI for microphone permission
                if (hasError) {
                    print("There is a problem with your microphone permissions")
                    Analytics.logEvent(AnalyticsKey.val(.microphone_permission_denied), parameters: nil)
                } else {
                    Analytics.logEvent(AnalyticsKey.val(.microphone_permission_granted), parameters: nil)
                }
            }
            params.bluetoothPowerErrorHandler = { (hasError: Bool) in
                // Update the UI for Bluetooth power
                if (hasError) { print("There is a problem with your Bluetooth power permissions")}
            }
            params.bluetoothPermissionErrorHandler = { (hasError: Bool) in
                // Update the UI for Bluetooth permission
                if (hasError) { print("There is a problem with your Bluetooth permissions")}
            }
        })

        super.init()
        
        createGSession()
    }
    
    func createGSession() {
        if gSession == nil {
            do {
                try gSession = GARSession(apiKey: firebaseKey, bundleIdentifier: nil)
            } catch let error as NSError {
                print("Couldn't start GoogleAR session: \(error)")
            }
        }
    }
    
    func setGlobalRoomName(_ name: String){
        roomManager.updateGlobalRoomName(name)
    }
    
    func beginGlobalSession(_ withPairing: Bool) {
        configureReachability()
        
        isPairingOrPaired = true

        roomManager.delegate = self
        
        if let session = gSession {
            session.delegate = self
            session.delegateQueue = DispatchQueue.main
        }
        
        if reachability?.currentReachabilityStatus() == .NotReachable {
            StateManager.updateState(.OFFLINE)
        } else if (withPairing == true) {
            StateManager.updateState(.LOOKING)
        }
        roomManager.findGlobalRoom(withPairing)
        
//        NotificationCenter.default.addObserver(forName: .UIApplicationDidEnterBackground, object: nil, queue: nil) { (notification) in
//            self.isPairingOrPaired = false
//        }
    }


    func beginPairing() {
        configureReachability()
        
        beginDiscoveryTimeout()
        
        isPairingOrPaired = true
        
        roomManager.delegate = self
        
        if let session = gSession {
            session.delegate = self
            session.delegateQueue = DispatchQueue.main            
        }

        // subscribe to Nearby messages
        messageSubscription = messageManager.subscription(messageFoundHandler: { (message: GNSMessage?) in
            print("PairingManager: beginPairing - subscription callback")
            if let roomMessage = message {
                let roomData = RoomData(roomMessage);
                let roomString = String(data: roomMessage.content, encoding: .utf8)
                print("Found message: \(String(describing:roomString))")

                self.roomManager.roomFound(roomData)

                // Cancel subscription
                self.messageSubscription = nil
                self.cancelDiscoveryTimeout()
           }
        }, messageLostHandler: { (message: GNSMessage?) in
            if let roomMessage = message {
                let messageString = String(data: roomMessage.content, encoding: .utf8)
                print("Lost sight of message: \(String(describing:messageString))")
            }
        })
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if appDelegate.pairingState == nil || appDelegate.pairingState != .OFFLINE {
            StateManager.updateState(.LOOKING)
        
            // build a room for potential use (if end up being the host)
            roomManager.createRoom()
        }
        
//        NotificationCenter.default.addObserver(forName: .UIApplicationDidEnterBackground, object: nil, queue: nil) { (notification) in
//            self.isPairingOrPaired = false
//        }
    }
    
    func resumeSession(fromDate: Date) {
        roomManager.resumeRoom()
    }
    
    func configureReachability() {
        let unreachableBlock = {
            DispatchQueue.main.async {
                StateManager.updateState(.OFFLINE)
                
                if self.isPairingOrPaired {
                    self.delegate?.offlineDetected()
                }
            }
        }
        
        // Check current state
        if let reachable = reachability?.isReachable(), reachable == false {
            unreachableBlock()
        }
        
        reachability?.reachableBlock = { reachability in
            if reachability?.currentReachabilityStatus() == .ReachableViaWiFi {
                print("Reachable via WiFi")
                StateManager.updateState(.NO_STATE)
            } else {
                print("Reachable via Cellular")
                StateManager.updateState(.NO_STATE)
            }
        }
        reachability?.unreachableBlock = { _ in
            print("Not reachable")
            unreachableBlock()
        }
        
        reachability?.startNotifier()
    }
    
    /// Send updated stroke to Firebase
    func updateStroke(_ stroke: Stroke) {
        roomManager.updateStroke(stroke)
    }
    
    func removeStroke(_ stroke: Stroke) {
        roomManager.updateStroke(stroke, shouldRemove: true)
    }
    
    func clearAllStrokes() {
        roomManager.clearAllStrokes()
    }
    
    /// Once host has made an initial drawing to share, and tapped done, send an ARAnchor based at drawing's node position to GARSession
    func setAnchor(_ anchor: ARAnchor) {
//        StateManager.updateState(.PARTNER_RESOLVE_ERROR)
//        pairingFailed()
//        roomManager.anchorFailedToResolve()

        do {
            try self.garAnchor = self.gSession?.hostCloudAnchor(anchor)
            NSLog("Attempting to Host Cloud Anchor: %@ with ARAnchor: %@", String(describing:garAnchor), String(describing:anchor))
        } catch let error as NSError {
            print("PairingManager: setAnchor: Hosting cloud anchor failed: \(error)")
        }
    }
    
    func setReadyToSetAnchor() {
        readyToSetAnchor = true
        roomManager.setReadyToSetAnchor()
        
        if (roomManager.isHost && partnerReadyToSetAnchor) {
            sendSetAnchorEvent();
        } else if (roomManager.isHost) {
            StateManager.updateState(.HOST_READY_AND_WAITING)
        } else if (partnerReadyToSetAnchor) {
            StateManager.updateState(.PARTNER_CONNECTING)
            beginPairingTimeout()
        } else {
            StateManager.updateState(.PARTNER_READY_AND_WAITING)
        }
    }
    
    func sendSetAnchorEvent() {
        print("sendSetAnchorEvent");
        delegate?.createAnchor()
        StateManager.updateState(.HOST_CONNECTING)
        beginPairingTimeout()
    }
    
    func retryResolvingAnchor() {
        print("PairingManager: retryResolvingAnchor")
        
        roomManager.retryResolvingAnchor()
        beginPairingTimeout()
    }
    
    func stopObservingLines() {
        roomManager.stopObservingLines()
    }
    
    func beginDiscoveryTimeout() {
        if discoveryTimeout == nil {
            discoveryTimeout = Timer.scheduledTimer(withTimeInterval: 10, repeats: false, block: { (timer) in
                print("PairingManager: beginDiscoveryTimeout - Discovery Timed Out")
                self.stopRoomDiscovery()
                StateManager.updateState(.DISCOVERY_TIMEOUT)
                
                self.roomManager.anchorFailedToResolve()
                Analytics.logEvent(AnalyticsKey.val(.pair_error_discovery_timeout), parameters: nil)
            })
        }
    }
    
    func cancelDiscoveryTimeout() {
        discoveryTimeout?.invalidate()
        discoveryTimeout = nil
    }

    
    func beginPairingTimeout() {
        if pairingTimeout == nil {
            pairingTimeout = Timer.scheduledTimer(withTimeInterval: 60, repeats: false, block: { (timer) in
                print("PairingManager: beginPairingTimeout - Pairing Timed Out")
                if (self.gSession != nil) {
                    self.gSession = nil
                    self.createGSession()
                }
                self.roomManager.isRetrying = false
                self.roomManager.anchorFailedToResolve()
                
                let params = [AnalyticsKey.val(.pair_error_sync_reason):AnalyticsKey.val(.pair_error_sync_reason_timeout)]
                Analytics.logEvent(AnalyticsKey.val(.pair_error_sync), parameters: params)
            })
        }
    }
    
    func cancelPairingTimeout() {
        self.roomManager.isRetrying = false
        pairingTimeout?.invalidate()
        pairingTimeout = nil
    }


}
    
// MARK: - RoomManagerDelegate
extension PairingManager : RoomManagerDelegate {
    func anchorIdCreated(_ id: String) {
        print("Resolving GARAnchor")
//        anchorObserver = self.garAnchor?.observe(\GARAnchor.cloudState, changeHandler: { (object, change) in
//            print("Observed a change to \(self.garAnchor?.cloudState), updated to: \(object.cloudState)")
//        })
        if self.gSession == nil {
            print ("There is a problem with your co-presence session" )
            pairingFailed()
            #if JOIN_GLOBAL_ROOM
            StateManager.updateState(.GLOBAL_RESOLVE_ERROR)
            #else
            StateManager.updateState(.PARTNER_RESOLVE_ERROR)
            #endif
            cancelPairingTimeout()
        }
        
        do {
            try self.garAnchor = self.gSession?.resolveCloudAnchor(withIdentifier: id)
        } catch let error as NSError{
            print("PairingManager:anchorIdCreated: Resolve Cloud Anchor Failed with Error: \(error)")
            pairingFailed()
            roomManager.anchorFailedToResolve()
            #if JOIN_GLOBAL_ROOM
            StateManager.updateState(.GLOBAL_RESOLVE_ERROR)
            #else
            StateManager.updateState(.PARTNER_RESOLVE_ERROR)
            #endif
            cancelPairingTimeout()
        }
    }
    
    func anchorResolved() {
        StateManager.updateState(.SYNCED)
        Analytics.logEvent(AnalyticsKey.val(.pair_success), parameters: nil)
        cancelPairingTimeout()
        roomManager.anchorResolved()
    }
    
    func anchorNotAvailable() {
        if isPairingOrPaired && roomManager.isRoomResolved {
            self.leaveRoom()
            delegate?.anchorWasReset()
        }
    }

    
    func localStrokeRemoved(_ stroke: Stroke) {
        delegate?.localStrokeRemoved(stroke)
    }

    func partnerStrokeUpdated(_ stroke: Stroke, id key:String) {
        delegate?.partnerStrokeUpdated(stroke, id:key)
    }

    func partnerStrokeRemoved(id key:String) {
        delegate?.partnerStrokeRemoved(id:key)
    }
    
    func partnerJoined(isHost: Bool, isPairing: Bool?) {
        delegate?.partnerJoined(isHost: isHost)
        
        #if JOIN_GLOBAL_ROOM
        
        #else
        if let pairing = isPairing, pairing == true {
            if (isHost) {
                StateManager.updateState(.HOST_CONNECTED)
            } else {
                StateManager.updateState(.PARTNER_CONNECTED)
            }
            stopRoomDiscovery()
        }
        #endif
    }
    
    func partnerLost() {
        if (isPairingOrPaired == true) {
            self.delegate?.partnerLost()
        }
    }
    
    func pairingFailed() {
        print("Pairing Failed")
        readyToSetAnchor = false
        partnerReadyToSetAnchor = false
    }
    
    func updatePartnerAnchorReadiness(partnerReady: Bool, isHost: Bool) {
        partnerReadyToSetAnchor = partnerReady

        if partnerReady && isHost {
            if (readyToSetAnchor) {
                sendSetAnchorEvent()
            }
        } else if partnerReady{
            if (readyToSetAnchor) {
                StateManager.updateState(.PARTNER_CONNECTING)
                beginPairingTimeout()
            }
        } else {
            partnerReadyToSetAnchor = false
        }
    }
    
    /// Stop Nearby pub/sub
    func stopRoomDiscovery() {
        messageSubscription = nil
        messagePublication = nil
        cancelDiscoveryTimeout()
    }
    
    func roomCreated(_ roomData: RoomData) {
        let message = roomData.getMessage()
        print("Room Created with Room Number: \(roomData.code)")
        messagePublication = messageManager.publication(with: message)
    }
    
    func leaveRoom() {
        roomManager.leaveRoom()
        stopRoomDiscovery()
        readyToSetAnchor = false
        partnerReadyToSetAnchor = false
        
    }
    
    func cancelPairing() {
        isPairingOrPaired = false
        leaveRoom()
        resetGSession()
    }
    
    func resetGSession() {
        gSession = nil
        
        // restart gar session so that it is available next tim
        createGSession()
    }
}

// MARK: - GARSessionDelegate
extension PairingManager: GARSessionDelegate {
    func session(_ session: GARSession, didResolve anchor: GARAnchor) {
        print("GARAnchor Resolved")
        self.delegate?.cloudAnchorResolved(anchor)
        self.anchorResolved()
    }
    
    func session(_ session: GARSession, didHostAnchor anchor: GARAnchor) {
        print("GARSession did host anchor")
        delegate?.cloudAnchorResolved(anchor)
        
        if anchor.cloudState == .success, let identifier = anchor.cloudIdentifier {
            roomManager.setAnchorId(identifier)
        } else {
            failHostAnchor(anchor)
        }
    }
    
    func session(_ session: GARSession, didFailToResolve anchor: GARAnchor) {
        print("GARSession did fail to resolve anchor: \(anchor.cloudState.rawValue)")
        #if JOIN_GLOBAL_ROOM
        StateManager.updateState(.GLOBAL_RESOLVE_ERROR)
        #else
        StateManager.updateState(.PARTNER_RESOLVE_ERROR)
        #endif
        pairingFailed()
        roomManager.anchorFailedToResolve()
        cancelPairingTimeout()
        
        var reason = ""
        if let _ = delegate?.isTracking() {
            reason = String(anchor.cloudState.rawValue)
        } else {
            reason = AnalyticsKey.val(.pair_error_sync_reason_not_tracking)
        }
        let params = [AnalyticsKey.val(.pair_error_sync_reason) : reason]
        Analytics.logEvent(AnalyticsKey.val(.pair_error_sync), parameters: params)
    }
    
    func session(_ session: GARSession, didFailToHostAnchor anchor: GARAnchor) {
        failHostAnchor(anchor)
    }
    
    
    func failHostAnchor(_ anchor: GARAnchor) {
        print("GARSession did fail to host anchor: \(anchor.cloudState.rawValue)")
        StateManager.updateState(.HOST_ANCHOR_ERROR)
        
        pairingFailed()
        roomManager.anchorFailedToResolve()
        cancelPairingTimeout()
        
        let params = [AnalyticsKey.val(.pair_error_sync_reason):String(anchor.cloudState.rawValue)]
        Analytics.logEvent(AnalyticsKey.val(.pair_error_sync), parameters: params)
    }
}
