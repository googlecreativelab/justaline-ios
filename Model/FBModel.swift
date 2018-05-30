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


protocol FBModel {
    static func from(_ dictionary: [String: Any?])->Self?
    func dictionaryValue()->[String: Any?]
}

enum FBKey: String {
    case anchor
    case updated_at_timestamp
    case lines
    case participants
    case displayName = "display_name"
    
    // FBAnchor
    case anchorId
    case hostCreatedAnchor
    case anchorProcessing
    case anchorResolutionError
    
    // FBParticipant
    case readyToSetAnchor
    case anchorResolved
    case pairing
    case lastSeen
    case lastSeenTimestamp = "timestamp"
    
    // Lines
    case points
    case lineWidth
    case creator
    
    static func val(_ key:FBKey)->String {
        return key.rawValue
    }
}
