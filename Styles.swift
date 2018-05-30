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

import UIKit

extension UILabel {
    override open func awakeFromNib() {
        let size = font.pointSize
        font = UIFont.systemFont(ofSize: size)
//        font = UIFont(name: "CoolSans-Medium", size: size)
    }
}

extension UIButton {
    override open func awakeFromNib() {
        if let size = titleLabel?.font.pointSize {
            titleLabel?.font = UIFont.systemFont(ofSize: size)
//            titleLabel?.font = UIFont(name: "CoolSans-Medium", size: size)
        }
    }
}

extension UITextView {
    override open func awakeFromNib() {
        if let size = font?.pointSize {
            font = UIFont.systemFont(ofSize: size)
//            font = UIFont(name: "CoolSans-Medium", size: size)
        }
    }
}
