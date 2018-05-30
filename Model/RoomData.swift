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

class RoomData {

    var code = ""

    var timestamp: Int64 = 0

    var message: GNSMessage!

    convenience init(code: String, timestamp: Int64) {
        let messageString = String("\(code),\(timestamp)")
        self.init(GNSMessage(content: messageString.data(using: .utf8)))

        self.code = code
        self.timestamp = timestamp
    }

    convenience init(_ message: GNSMessage) {
        self.init()
        self.message = message

        if let messageString = String(data: message.content, encoding: .utf8) {
            let parts = messageString.split(separator: ",")

            // Missing error state handling which got complicated
            if (parts.count == 2) {
                code = String(parts[0])
                timestamp = Int64(parts[1])!
            }
        }
    }

    func getMessage()->GNSMessage {
        return message
    }
}

enum MalformedDataError: Error {
    case invalidFormat(String)
}
