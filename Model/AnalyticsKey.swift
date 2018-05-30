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

enum AnalyticsKey: String {
    case value_true = "true"
    
    // Permissions
    case camera_permission_granted
    case camera_permission_denied
    case microphone_permission_granted
    case microphone_permission_denied
    case storage_permission_granted
    case storage_permission_denied
    
    // Camera view
    case record
    case record_method
    case record_method_tap = "tap"
    case record_method_hold = "hold"
    
    // User properties
    case user_has_drawn
    case tracking_has_established
    case user_tapped_undo
    case user_tapped_clear
    case tapped_share_app
    
    // Playback
    case tapped_save
    case tapped_share_recording
    
    // Pairing
    case tapped_start_pair
    case pair_error_discovery_timeout
    case tapped_ready_to_set_anchor
    case pair_error_sync
    case pair_error_sync_reason = "reason"
    case pair_error_sync_reason_timeout = "Pairing Timeout"
    case pair_error_sync_reason_not_tracking
    case pair_success
    case user_tapped_pair
    case tapped_exit_pair_flow
    case tapped_disconnect_paired_session
    
    static func val(_ key:AnalyticsKey)->String {
        return key.rawValue
    }
}
