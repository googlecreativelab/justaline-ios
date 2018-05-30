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
import Firebase
import FirebaseAuth
import FirebaseDatabase
import FirebaseAnalytics


protocol RoomManagerDelegate {
    func localStrokeRemoved(_ stroke: Stroke)
    func updatePartnerAnchorReadiness(partnerReady: Bool, isHost: Bool)
    func partnerJoined(isHost: Bool, isPairing: Bool?)
    func pairingFailed()
    func partnerLost()
    func partnerStrokeUpdated(_ stroke: Stroke, id key: String)
    func partnerStrokeRemoved(id key: String)
    func anchorIdCreated(_ id: String)
    func anchorNotAvailable()
    func anchorResolved()
    func roomCreated(_ roomData: RoomData)
    func leaveRoom()
}

class RoomManager: StrokeUploaderDelegate {
    // MARK: Variables
    
    /// Auth
    var firebaseAuth: Auth?

    /// User ID
    var userUid: String?
    
    /// Store anchor id after it is added to prevent repeatedely resolving
    var anchorId: String?

    /// Delegate property for PairingManager
    var delegate: RoomManagerDelegate?
    
    var strokeUploader: StrokeUploadManager

    var hasStrokeData: Bool = false

    var isHost: Bool = false    

    private let ROOT_FIREBASE_ROOMS = "rooms"
    
    var ROOT_GLOBAL_ROOM = "global_room_0"
    
    private let DISPLAY_NAME_VALUE = "Just a Line"

    private var app: FirebaseApp?

    private var roomRef: DatabaseReference?
    
    private var roomKey: String?
    
    private var roomCodeRef: DatabaseReference?

    private var hotspotListRef: DatabaseReference?
    private var roomsListRef: DatabaseReference?
    private var participantsRef: DatabaseReference?
    private var strokesRef: DatabaseReference?

    
    private var globalRoomRef: DatabaseReference?

    var isRoomResolved: Bool = false
    
    private var anchorValueHandle: UInt?

    private var anchorRemovedHandle: UInt?

    private var lineAddedHandle: UInt?
    
    private var partners = [String]()
    
    private var partnerAddedHandle: UInt?
    
    private var partnerUpdatedHandle: UInt?
    
    private var partnerRemovedHandle: UInt?
    
    private var partnerMovedHandle: UInt?
    
    private var strokeAddedHandle: UInt?

    private var strokeUpdatedHandle: UInt?

    private var strokeRemovedHandle: UInt?
    
    private var strokeMovedHandle: UInt?

    private var localStrokeUids = [String: Stroke]()
    
    /// Flag to indicate that we are using the global room, but pairing and resolving an anchor
    private var pairing: Bool = false
    
    var isRetrying = false

//    private var stroke

    // MARK: - Initialization
    
    init() {
        strokeUploader = StrokeUploadManager()
        strokeUploader.delegate = self

        // Firebase setup
        firebaseAuth = Auth.auth()
        firebaseLogin()

        app = FirebaseApp.app()
        if (app != nil) {
            let rootRef = Database.database().reference()
            roomsListRef = rootRef.child(ROOT_FIREBASE_ROOMS)
            globalRoomRef = rootRef.child(ROOT_GLOBAL_ROOM)
            
            DatabaseReference.goOnline();
        } else {
            print("RoomManager: Could not connect to Firebase Database!")
            roomsListRef = nil
            globalRoomRef = nil
        }
    }
    
    func updateGlobalRoomName(_ name: String) {
        let rootRef = Database.database().reference()
        ROOT_GLOBAL_ROOM = name
        globalRoomRef = rootRef.child(ROOT_GLOBAL_ROOM)
    }

    /// Login with existing id or create a new one
    private func firebaseLogin() {
        if let currentUser = firebaseAuth?.currentUser {
            userUid = currentUser.uid
            print("firebaseLogin: user uid \(String(describing:userUid))")
        } else {
            loginAnonymously();
        }
    }

    /// Create new user id with anonymous sign-in
    private func loginAnonymously() {
        firebaseAuth?.signInAnonymously(completion: { (user, error) in
            // need to handle error states
            if (error == nil) {
                if let currentUser = self.firebaseAuth?.currentUser {
                    self.userUid = currentUser.uid
                    print("loginAnonymously: user uid \(String(describing: self.userUid))")
                }
            }
        })
    }
    
    // MARK: - Room Flow
    
    /// When pairing both users create a room
    func createRoom() {
        print("RoomManager:createRoom")
        
        if let room = roomsListRef?.childByAutoId() {
            updateRoomReference(room)
        }
        
        print("RoomManager:createRoom: Trying Room Number: \(String(describing:(roomRef?.key)))")
        
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        self.roomRef?.child(FBKey.val(.updated_at_timestamp)).setValue(timestamp)
        self.roomRef?.child(FBKey.val(.displayName)).setValue(self.DISPLAY_NAME_VALUE)
        
        pairing = true
        participateInRoom()
        
        if let roomString = roomKey {
            let roomData = RoomData(code: roomString, timestamp: timestamp)
            self.delegate?.roomCreated(roomData)
        } else {
            StateManager.updateState(.UNKNOWN_ERROR)
        }

    }
    
    /// Takes database ref for either new or joined room and updates the key and participants ref
    ///
    /// - Parameter room: Database Reference for firebase room
    func updateRoomReference(_ room: DatabaseReference) {
        roomRef = room
        roomKey = room.key
    }
    
    
    /// Add self as a participant in the current room
    func participateInRoom() {
        if let uid = self.userUid, let partnersRef = roomRef?.child(FBKey.val(.participants)) {
            participantsRef = partnersRef
            
            // Add to participants list with false value until room is resolved for the originating user to discover
            let participant = FBParticipant(readyToSetAnchor: false)
            participant.isPairing = pairing

            partnersRef.child(uid).setValue(participant.dictionaryValue())
            partnersRef.child(uid).onDisconnectSetValue(nil)
            self.partnerJoinedCallbacks(uid:uid, reference:partnersRef)
        }
    }
    

    /// RoomData conveyed via Nearby
    func roomFound(_ roomData: RoomData) {
        if (shouldJoinRoom(roomData)) {            
            self.delegate?.leaveRoom()

            joinRoom(roomKey: roomData.code)
        }
    }
    
    func findGlobalRoom(_ withPairing: Bool = false) {
        guard let globalRoom = globalRoomRef else {
            return
        }
        pairing = withPairing
        
        globalRoom.observeSingleEvent(of: .value) { (snapshot) in
            if let roomString = snapshot.value as? String {
                self.joinRoom(roomKey: roomString)
            }
        }
    }
    
    /// If no room has been created, join, otherwise only choose if my room number is lower
    private func shouldJoinRoom(_ roomData: RoomData)->Bool {
        guard let roomString = self.roomKey else {
            return true
        }
        return roomString.compare(roomData.code) == ComparisonResult.orderedDescending
    }
    
    
    /// Adds user id to participants list, and begins watching for an anchor
    func joinRoom(roomKey: String) {
        print("RoomManager:joinRoom: Joining Room: \(roomKey)")
        guard let _ = app, let _ = userUid else {
            return
        }
        
        if let room = roomsListRef?.child(roomKey) {
            updateRoomReference(room)
            participateInRoom()
            
            #if JOIN_GLOBAL_ROOM
            // if pairing with another device, remove anchor to start fresh
            // otherwise try to obtain an existing anchor id
            if pairing == false {
                self.observeAnchor()
            }
            #endif
        }
    }
    
    func resumeRoom() {
        guard let _ = roomRef else {
            return
        }
        
        participateInRoom()        
    }
    
    
    /// Sets Firebase flags for participant and anchor, begins observing stroke ref for child changes
    func resolveRoom() {
        guard let room = roomRef, let uid = userUid else {
            return
        }
        
        self.isRoomResolved = true
        
        let participant = FBParticipant(anchorResolved: true, isPairing: false)
        participantsRef?.child(uid).setValue(participant.dictionaryValue())
        room.child(FBKey.val(.anchor)).child(FBKey.val(.anchorResolutionError)).setValue(false)
    }
    
    func stopObservingLines() {
        print("Stopped observing lines")
        if let handle = strokeAddedHandle {
            strokesRef?.removeObserver(withHandle: handle)
        }
        
        if let handle = strokeUpdatedHandle {
            print ("stroke update handle removed for \(String(describing: strokesRef))")
            strokesRef?.removeObserver(withHandle: handle)
        }
        
        if let handle = strokeRemovedHandle {
            strokesRef?.removeObserver(withHandle: handle)
        }
        
        if let handle = strokeMovedHandle {
            strokesRef?.removeObserver(withHandle: handle)
        }
        strokesRef?.removeAllObservers()
    }
    
    
    func leaveRoom() {
        isRoomResolved = false
        isHost = false
        
        partners.removeAll()
        localStrokeUids.removeAll()
        
        if let handle = partnerAddedHandle {
            participantsRef?.removeObserver(withHandle: handle)
        }

        if let handle = partnerUpdatedHandle {
            participantsRef?.removeObserver(withHandle: handle)
        }

        if let handle = partnerRemovedHandle {
            participantsRef?.removeObserver(withHandle: handle)
        }

        if let handle = partnerMovedHandle {
            participantsRef?.removeObserver(withHandle: handle)
        }
        
        stopObservingLines()
        participantsRef?.removeAllObservers()
        anchorId = nil
        anchorValueHandle = nil
        anchorRemovedHandle = nil
        partnerAddedHandle = nil
        partnerUpdatedHandle = nil
        partnerRemovedHandle = nil
        partnerMovedHandle = nil
        strokeAddedHandle = nil
        strokeUpdatedHandle = nil
        strokeRemovedHandle = nil
        strokeMovedHandle = nil
        strokesRef = nil

        guard let room = roomRef, let uid = userUid else {
            return
        }
        // remove user from participants list
        participantsRef?.child(uid).removeValue()
        participantsRef = nil
        
        if let handle = anchorValueHandle {
            room.removeObserver(withHandle: handle)
        }
        
        if let handle = anchorRemovedHandle {
            room.removeObserver(withHandle: handle)
        }
        room.removeAllObservers()
        
        roomRef = nil
        roomKey = nil
    }
    
    
    // MARK: Partner Callbacks
    
    /// Observers for "participants" DatabaseReference. When participant is initially added, their id is the key,
    /// and the value indicates whether the anchor has been resolved
    ///
    /// - Parameters:
    ///   - uid: userUid value
    ///   - reference: path to participants in FB
    func partnerJoinedCallbacks(uid: String, reference: DatabaseReference) {
        print("Partner Callbacks Reference: \(reference)")
        // Partner Added
        self.partnerAddedHandle = reference.observe(.childAdded, with: { (snapshot) in
            print("RoomManager:partnerJoinedCallbacks: Partner Added Observer")
            
            if snapshot.key != uid {
                if let participantDict = snapshot.value as? [String: Any?] {
                    self.partners.append(snapshot.key)
                    let participant = FBParticipant.from(participantDict)
                    
                    if participant?.isPairing == true && self.pairing == true {
                        // Host for global room pairing is alphabetical since we don't establish with Nearby pub/sub
                        let keyComparison = uid.compare(snapshot.key)
                        self.isHost = (keyComparison == ComparisonResult.orderedDescending) ? false : true
                        
                        #if JOIN_GLOBAL_ROOM
                        let state:State = (self.isHost) ? .HOST_CONNECTED : .PARTNER_CONNECTED
                        StateManager.updateState(state)
                        #endif
                        
                    }
                    self.delegate?.partnerJoined(isHost: self.isHost, isPairing: participant?.isPairing)
                }
            }
        }) { (error) in
            print("Partner Added Observer Cancelled")
        }
        
        // Partner Changed
        self.partnerUpdatedHandle = reference.observe(.childChanged, with: { (snapshot) in
            print("RoomManager:partnerJoinedCallbacks: Partner Changed Observer")
            if let participantDict = snapshot.value as? [String: Any?], let participant = FBParticipant.from(participantDict)
                , snapshot.key != uid {
                
                self.delegate?.updatePartnerAnchorReadiness(partnerReady: participant.readyToSetAnchor, isHost: self.isHost)
                
                // if host is true, we are pairing (when partner finishes resolving room, they set isPairing to false) and can resolve room
                // if partner, host still hasn't resolved room, so isPairing is still true
                if (participant.anchorResolved == true && (self.isHost == true)) { // || participant.isPairing == true)) {
                    self.delegate?.anchorResolved()
                }
            }
        }) { (error) in
            print("Partner Changed Observer Cancelled")
        }
        
        // Partner Removed
        self.partnerRemovedHandle = reference.observe(.childRemoved, with: { (snapshot) in
            print("RoomManager:partnerJoinedCallbacks: Partner Removed Observer")
            if let partnerIndex = self.partners.index(of: snapshot.key) {
                self.partners.remove(at: partnerIndex)
                if self.partners.count < 1 {
                    self.delegate?.partnerLost()
                }
            }
            if let participantDict = snapshot.value as? [String: Any?], snapshot.key != uid {
                let participant = FBParticipant.from(participantDict)
                if participant?.isPairing == true {
                    StateManager.updateState(.CONNECTION_LOST)
                }
            }
            
            
        }) { (error) in
            print("Partner Removed Observer Cancelled")
        }
        
        // Unused
        self.partnerMovedHandle = reference.child(uid).observe(.childMoved, with: { (snapshot) in
            
        }) { (error) in
            print("RoomManager:partnerJoinedCallbacks: Partner Moved Observer Cancelled")
        }
    }

    // MARK: - Anchor Flow
    
    func observeAnchor() {
        guard let room = roomRef else {
            return
        }
        let anchorUpdateRef = room.child(FBKey.val(.anchor))
        
        // Clear anchor before adding creation listener, except in global room when not pairing
        #if !JOIN_GLOBAL_ROOM
        anchorUpdateRef.removeValue()
        #else
        if pairing == true {
        anchorUpdateRef.removeValue()
        }
        #endif
        
        anchorValueHandle = anchorUpdateRef.observe(.value, with: { (dataSnapshot) in
            print("Anchor Value Callback Reference: \(anchorUpdateRef)")

            if let anchorValue = dataSnapshot.value as? [String: Any?] {
                print("RoomManager:observeAnchor: FBAnchor object found")
                
                // Create anchor object from Firebase model
                if let anchor = FBAnchor.from(anchorValue) {
                    
                    // Return anchor
                    if anchor.anchorResolutionError == true {
                        
                        // When Joining a global room, if there is a pre-exisintg anchor error, need to show special error
                        var shouldUseGlobalError = false
                        #if JOIN_GLOBAL_ROOM
                        if (self.pairing == false) {
                            shouldUseGlobalError = true
                        }
                        #endif

                        // Even in global pairing (not global joining), we want to set state to host or partner errors
                        if self.isHost || !shouldUseGlobalError {
                            StateManager.updateState(.HOST_RESOLVE_ERROR)
                        } else if !shouldUseGlobalError {
                            StateManager.updateState(.PARTNER_RESOLVE_ERROR)
                        } else {
                            StateManager.updateState(.GLOBAL_NO_ANCHOR)
                        }
                        self.delegate?.pairingFailed()

                        // If there's an anchor error, reset readyToSetAnchor value
                        if let uid = self.userUid {
                            self.participantsRef?.child(uid).child(FBKey.val(.readyToSetAnchor)).setValue(false)
                        }
                        
                    } else if let anchorId = anchor.anchorId, self.isHost == false, self.anchorId != anchorId {
                        print("RoomManager:observeAnchor: Anchor ID found: \(String(describing:anchor.anchorId))")
                        self.anchorId = anchorId
                        
                        var state: State = .PARTNER_CONNECTING
                        #if JOIN_GLOBAL_ROOM
                        if self.pairing == false {
                            state = .GLOBAL_CONNECTING
                        }
                        #endif
                        
                        StateManager.updateState(state)
                        self.delegate?.anchorIdCreated(anchorId)
                    }
                    
                    // Stop watching for anchor changes
//                    anchorUpdateRef.removeAllObservers()
                }
            } else {
                #if JOIN_GLOBAL_ROOM
                if (self.pairing == false) {
                    StateManager.updateState(.GLOBAL_NO_ANCHOR)
                }
                #endif
            }
        }) { (error) in
            print("RoomManager:observeAnchor: Anchor Observe Cancelled")
        }
        
        print("Anchor Removed Callback Reference: \(room)")
        anchorRemovedHandle = room.observe(.childRemoved, with: { (snapshot) in
            if snapshot.key == FBKey.val(.anchor) {
                print("RoomManager:observeAnchor: Anchor object removed")
                self.delegate?.anchorNotAvailable()
            }
        })
    }
    
    func setReadyToSetAnchor() {
        guard let partnersRef = participantsRef, let uid = userUid else {
            return
        }
        
        self.observeAnchor()

        let participant = FBParticipant(readyToSetAnchor: true)
        partnersRef.child(uid).setValue(participant.dictionaryValue())
    }
    
    /// After resolving cloud anchor, set cloud identifier in Firebase for partner to discover
    func setAnchorId(_ identifier: String) {
        guard let room = roomRef else {
            return
        }
        
        self.anchorId = identifier
        let fbAnchor = FBAnchor(anchorId: identifier)
        room.child(FBKey.val(.anchor)).setValue(fbAnchor.dictionaryValue())
    }
    
    func retryResolvingAnchor() {
        isRoomResolved = false

        if let anchor = self.anchorId {
            isRetrying = true
            localStrokeUids.removeAll()
            delegate?.anchorIdCreated(anchor)
        } else {
            delegate?.pairingFailed()
        }
    }
    
    func anchorResolved() {
        if (isRoomResolved == false) {
            self.resolveRoom()
            self.observeLines()
            isHost = false
        }
    }
    
    func anchorFailedToResolve() {
        guard let room = roomRef else {
            return
        }
        
        print("RoomManager: anchorFailedToResolve")
        
        if (!isRetrying) {
        
            // For global rooms, only send failure to Firebase if it is a hosting failure
            #if JOIN_GLOBAL_ROOM
                if (pairing) {
                    let fbAnchor = FBAnchor(anchorResolutionError: true)
                    room.child(FBKey.val(.anchor)).setValue(fbAnchor.dictionaryValue())
                }
            #else
                let fbAnchor = FBAnchor(anchorResolutionError: true)
                room.child(FBKey.val(.anchor)).setValue(fbAnchor.dictionaryValue())
            #endif
        }
    }
    
    // MARK: - Strokes
    
    /// Watch for changes to lines db ref
    func observeLines() {
        guard let room = roomRef, let uid = userUid else {
            return
        }
        strokesRef = room.child(FBKey.val(.lines))
        self.strokeUpdateCallbacks(uid: uid, reference: strokesRef!)
    }

    
    /// Gateway for all stroke changes besides clear all
    /// Updates locally drawn strokes or adds them if they do not already exist
    func updateStroke(_ stroke: Stroke, shouldRemove: Bool = false) {
        let localStrokeMatch = localStrokeUids.contains { (key, localStroke) -> Bool in
            localStroke == stroke
        }
        
        if localStrokeMatch == false {
            addStroke(stroke)
        }
        strokeUploader.queueStroke(stroke, remove: shouldRemove)
    }
    
    private func addStroke(_ stroke: Stroke) {
        guard let room = roomRef, let uid = userUid else {
            return
        }
        
        let strokeRef = room.child(FBKey.val(.lines)).childByAutoId()
        localStrokeUids[strokeRef.key] = stroke
        stroke.creatorUid = uid
        stroke.fbReference = strokeRef
    }
    
    func clearAllStrokes() {
        guard let room = roomRef else {
            return
        }
        
        room.child(FBKey.val(.lines)).removeValue()
    }
    
    // MARK: StrokeUploadManager Delegate methods
    func uploadStroke(_ stroke: Stroke, completion: @escaping ((Error?, DatabaseReference) -> Void)) {
        guard let fbStrokeRef = stroke.fbReference else {
            return
        }
        if(stroke.previousPoints == nil){
            let dictValue = stroke.dictionaryValue()
            print("New Stroke dict: \(dictValue)")
            if (dictValue.count == 0 || stroke.node == nil) {
                print("RoomManager: uploadStroke: Stroke new upload cancelled, stroke removed")
                delegate?.localStrokeRemoved(stroke)
            } else {
                fbStrokeRef.setValue(dictValue, withCompletionBlock: completion)
            }
        } else {
            let dictValue = stroke.pointsUpdateDictionaryValue()
            print("Stroke update dict: \(dictValue)")
            if (dictValue.count == 0 || stroke.node == nil) {
                print("RoomManager: uploadStroke: Stroke update upload cancelled, stroke removed")
                delegate?.localStrokeRemoved(stroke)
            } else {
                fbStrokeRef.child(FBKey.val(.points)).updateChildValues(dictValue, withCompletionBlock: completion)
            }
        }
    }
    
    func removeStroke(_ stroke: Stroke) {
        delegate?.localStrokeRemoved(stroke)
        stroke.fbReference?.removeValue()
    }
    
    
    // MARK: Stroke Callbacks
    
    /// Observers for changes to partner's lines
    private func strokeUpdateCallbacks(uid: String, reference: DatabaseReference) {
        print("Stroke Update Callbacks Reference: \(reference)")

        self.strokeAddedHandle = reference.observe(.childAdded, with: { (snapshot) in
            if  let strokeValue = snapshot.value as? [String: Any?],
                self.localStrokeUids[snapshot.key] == nil,
                let stroke = Stroke.from(strokeValue) {
                    print("RoomManager:strokeUpdateCallbacks: Partner Stroke Added Observer")
                    stroke.drawnLocally = false
                    self.delegate?.partnerStrokeUpdated(stroke, id: snapshot.key)
            } else if let _ = snapshot.value as? [String: Any?], self.localStrokeUids[snapshot.key] != nil {
                self.hasStrokeData = true
            } else {
                print("RoomManager:strokeUpdateCallbacks: Added Observer has wrong value: \(String(describing: snapshot.value))")
            }
        }) { (error) in
            print("Partner Stroke Added Observer Cancelled")
        }

        self.strokeUpdatedHandle = reference.observe(.childChanged, with: { (snapshot) in
            if let strokeValue = snapshot.value as? [String: Any?], self.localStrokeUids[snapshot.key] == nil,
               let stroke = Stroke.from(strokeValue) {
//                    print("RoomManager:strokeUpdateCallbacks: Partner Stroke Changed Observer")
                    stroke.drawnLocally = false
                    self.delegate?.partnerStrokeUpdated(stroke, id: snapshot.key)
            }
        }) { (error) in
            print("Partner Stroke Changed Observer Cancelled")
        }

        self.strokeRemovedHandle = reference.observe(.childRemoved, with: { (snapshot) in
            print("Partner Stroke Removed Observer")
            if let stroke = self.localStrokeUids[snapshot.key] {
                self.delegate?.localStrokeRemoved(stroke)
                self.localStrokeUids[snapshot.key] = nil
            } else {
                self.delegate?.partnerStrokeRemoved(id: snapshot.key)
            }
        }) { (error) in
            print("RoomManager:strokeUpdateCallbacks: Partner Stroke Removed Observer Cancelled")
        }

        self.strokeMovedHandle = reference.observe(.childMoved, with: { (snapshot) in

        }) { (error) in
            print("Partner Stroke Moved Observer Cancelled")
        }
    }

}
