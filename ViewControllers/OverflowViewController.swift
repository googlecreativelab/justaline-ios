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

protocol OverflowViewControllerDelegate {
    func shareButtonTapped(_ sender: UIButton)
    func aboutButtonTapped(_ sender: UIButton)
}
class OverflowViewController: UIViewController {
    
    @IBOutlet weak var overlayButton: UIButton!
    @IBOutlet weak var buttonContainer: UIView!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var aboutButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    var delegate: OverflowViewControllerDelegate?
    var offscreenContainerPosition: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        shareButton.setTitle(NSLocalizedString("menu_share_app", comment: "Share App"), for: .normal)
        aboutButton.setTitle(NSLocalizedString("menu_about", comment: "About"), for: .normal)
        cancelButton.setTitle(NSLocalizedString("cancel", comment: "Cancel"), for: .normal)
        
        offscreenContainerPosition = buttonContainer.frame.size.height
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        buttonContainer.transform = CGAffineTransform.init(translationX: 0, y: offscreenContainerPosition)
        UIView.animate(withDuration: 0.25, animations: {
            self.buttonContainer.transform = .identity
        }) { (success) in
            UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.shareButton)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        UIView.animate(withDuration: 0.35) {
            self.buttonContainer.transform = CGAffineTransform.init(translationX: 0, y: self.offscreenContainerPosition)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func shareButtonTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: {
            self.delegate?.shareButtonTapped(sender)
        })
    }
    
    @IBAction func aboutButtonTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: {
            self.delegate?.aboutButtonTapped(sender)
        })
        
    }
    
    @IBAction func cancelTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
