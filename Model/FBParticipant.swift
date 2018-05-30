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

final class FBParticipant: FBModel {
    static func from(_ dictionary: [String: Any?]) -> FBParticipant? {
        let participant = FBParticipant()
        if let readyToSetAnchor = dictionary[FBKey.val(.readyToSetAnchor)] as? Bool {
            participant.readyToSetAnchor = readyToSetAnchor
        }
        if let anchorResolved = dictionary[FBKey.val(.anchorResolved)] as? Bool {
            participant.anchorResolved = anchorResolved
        }
        if let isPairing = dictionary[FBKey.val(.pairing)] as? Bool {
            participant.isPairing = isPairing
        }

        return participant        
    }
    
    var readyToSetAnchor: Bool = false
    
    var anchorResolved: Bool = false
    
    var isPairing: Bool = false
    
    var lastSeen = [String: Any?]()
    
    convenience init(anchorResolved: Bool, isPairing: Bool) {
        self.init()
        
        self.anchorResolved = anchorResolved
        self.isPairing = isPairing
        
        self.lastSeen[FBKey.val(.lastSeenTimestamp)] = newTimestamp()
    }
    
    convenience init(readyToSetAnchor: Bool) {
        self.init()
        
        self.readyToSetAnchor = readyToSetAnchor
        self.lastSeen[FBKey.val(.lastSeenTimestamp)] = newTimestamp()
        self.isPairing = true
    }
    
    
    func dictionaryValue()->[String: Any?] {
        var dictionary = [String: Any?]()
        dictionary[FBKey.val(.readyToSetAnchor)] = readyToSetAnchor
        dictionary[FBKey.val(.anchorResolved)] = anchorResolved
        dictionary[FBKey.val(.pairing)] = isPairing
        dictionary[FBKey.val(.lastSeen)] = lastSeen
        
        return dictionary
    }
    
    func newTimestamp ()->Int64 {
        let timestampInteger = Int64(Date().timeIntervalSince1970 * 1000)
        return timestampInteger
    }
}
