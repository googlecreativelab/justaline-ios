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
import FirebaseDatabase

struct StrokeUpdate {
    var stroke: Stroke
    var shouldRemove: Bool
}

protocol StrokeUploaderDelegate {
    func removeStroke(_ stroke: Stroke)
    func uploadStroke(_ stroke: Stroke, completion: @escaping ((Error?, DatabaseReference) -> Void))
}

class StrokeUploadManager {
    var uploadingStrokeKeys: [String]
    
    var queuedUpdates: [String: StrokeUpdate]
    
    var delegate: StrokeUploaderDelegate?
    
    let queue: DispatchQueue
    
    init() {
        uploadingStrokeKeys = [String]()
        queuedUpdates = [String: StrokeUpdate]()
        queue = DispatchQueue(label: "uploadQueue", attributes: .concurrent)
    }
    
    func queueStroke(_ stroke: Stroke, remove: Bool) {
        guard let key = stroke.fbReference?.key else {
            return
        }
        let update = StrokeUpdate(stroke: stroke, shouldRemove: remove)
        queue.sync {
            if (uploadingStrokeKeys.count == 0) {
                print("StrokeUploadManager: queueStroke: uploading stroke \(String(describing: update.stroke.fbReference?.key)) with \(uploadingStrokeKeys.count) keys")
                upload(update)
            } else {
                print("Queued Updates Count: \(queuedUpdates.count)")
                print("Stroke size: \(stroke.points.count)")
                queuedUpdates[key] = update
            }
        }
    }
    
    func upload(_ update: StrokeUpdate) {
        if update.shouldRemove {
            delegate?.removeStroke(update.stroke)
        } else {
            guard let strokeKey = update.stroke.fbReference?.key else {
                return
            }
            queue.async(flags: .barrier) {
                print("StrokeUploadManager: upload: move \(strokeKey) from queue to uploading")
                self.uploadingStrokeKeys.append(strokeKey)
                self.queuedUpdates[strokeKey] = nil
                self.delegate?.uploadStroke(update.stroke, completion: { (error, reference) in
                    print("StrokeUploadManager: upload: attempting to remove stroke key \(strokeKey)")
                    if let strokeIndex = self.uploadingStrokeKeys.index(of: strokeKey) {
                        print("StrokeUploadManager: upload: successfully removed stroke key at \(strokeIndex)")
                        self.uploadingStrokeKeys.remove(at: strokeIndex)
                    }
                    if (error == nil) {
                        for (_, update) in self.queuedUpdates {
                            self.queueStroke(update.stroke, remove: update.shouldRemove)
                        }
                    } else {
                        // clear out any stroke that is causing upload errors
                        print("Error uploading lines: \(String(describing: error))")
                        self.delegate?.removeStroke(update.stroke)
                    }
                })
            }
        }
    }
    
    func resetQueue() {
        queue.async(flags: .barrier) {
            self.uploadingStrokeKeys.removeAll()
            self.queuedUpdates.removeAll()
        }
    }
}
