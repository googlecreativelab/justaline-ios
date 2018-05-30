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

//
//  Pt.swift
//  JustALine
//
//  Created by Adrian Harris Crowne on 3/28/18.
//  Copyright © 2018 Google Inc. All rights reserved.
//

import SceneKit

@objc class Pt: NSObject, NSCopying {
    var sessionCoord = SCNVector3Zero
    
    convenience init (sessionCoord: SCNVector3) {
        self.init()
        
        self.sessionCoord = sessionCoord
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        var vector = SCNVector3Make(sessionCoord.x, sessionCoord.y, sessionCoord.z)
        return Pt(sessionCoord: vector)
    }
}
