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


final class FBAnchor: FBModel {
    static func from(_ dictionary: [String: Any?]) -> FBAnchor? {
        var anchor: FBAnchor?
        
        if let anchorId = dictionary[FBKey.val(.anchorId)] as? String {
            anchor = FBAnchor(anchorId: anchorId)
        } else {
            if let anchorError = dictionary[FBKey.val(.anchorResolutionError)] as? Bool {
                anchor = FBAnchor(anchorResolutionError: anchorError)
            }
        }
        
        return anchor
    }
    
    

    var anchorId: String?

    var anchorResolutionError: Bool = false

    convenience init(anchorId: String) {
        self.init()
        
        self.anchorId = anchorId
        self.anchorResolutionError = false
    }

    convenience init(anchorResolutionError: Bool) {
        self.init()
        
        self.anchorResolutionError = anchorResolutionError
    }
    
    func dictionaryValue()->[String: Any?] {
        var dictionary = [String: Any?]()
        dictionary[FBKey.val(.anchorId)] = anchorId
        dictionary[FBKey.val(.anchorResolutionError)] = anchorResolutionError
        
        return dictionary
    }

}
