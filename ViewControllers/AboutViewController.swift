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

class AboutViewController: UIViewController, UITextViewDelegate {

    @IBOutlet weak var learnMoreTextView: UITextView!
    @IBOutlet weak var privacyButton: UIButton!
    @IBOutlet weak var thirdPartyButton: UIButton!
    @IBOutlet weak var termsButton: UIButton!
    @IBOutlet weak var buildLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let closeButton = UIBarButtonItem(image: UIImage(named: "ic_close"), style: .plain, target: self, action: #selector(closeTapped))
        closeButton.accessibilityLabel = NSLocalizedString("menu_close", comment: "Close")

        self.navigationItem.leftBarButtonItem = closeButton

        formatButton(termsButton, stringKey: "terms_of_service")
        formatButton(privacyButton, stringKey: "privacy_policy")
        formatButton(thirdPartyButton, stringKey: "third_party_licenses")
        formatLearnMore()
        
        let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        let buildString = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as! String
        buildLabel.text = "\(versionString)(\(buildString))"        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func buttonTapped(_ sender: UIButton) {
        var urlString: String?
        if sender == termsButton {
            urlString = "terms_url"
        } else if sender == privacyButton {
            urlString = "privacy_policy_url"
        }
        
        if let urlKey = urlString {
            UIApplication.shared.open(URL(string:NSLocalizedString(urlKey, comment: ""))!, options: [:], completionHandler: nil)
        }
    }
    
    @objc func closeTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "unwindAboutSegue", sender: self)
    }
    
    func formatButton(_ button: UIButton, stringKey: String) {
        let attributedString = NSAttributedString(string: NSLocalizedString(stringKey, comment: ""),
                                                  attributes: [.underlineStyle: NSUnderlineStyle.styleSingle.rawValue,
//                                                               .font: UIFont(name: "CoolSans-Medium", size: 11)!,
                                                               .font: UIFont.systemFont(ofSize: 11),
                                                               .foregroundColor: UIColor.white,
                                                               .underlineColor: UIColor.white])
        button.setAttributedTitle(attributedString, for: .normal)
    }
    
    func formatLearnMore() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 6
        
        let learnMoreString = NSMutableAttributedString(string: NSLocalizedString("about_text", comment: "Just a Line is an AR Experiment..."), attributes: [.paragraphStyle: paragraphStyle, .foregroundColor: UIColor.white])
        learnMoreTextView.linkTextAttributes = [NSAttributedStringKey.foregroundColor.rawValue: UIColor.white]
        let linkRange = (learnMoreString.string as NSString).range(of:NSLocalizedString("about_text_link", comment: "g.co/justaline"))
        
        learnMoreString.addAttribute(.underlineStyle,
                                     value: NSUnderlineStyle.styleSingle.rawValue,
                                     range: linkRange)
        
        learnMoreString.addAttribute(.link,
                                     value: URL(string: NSLocalizedString("jal_url", comment: "https://g.co/justaline"))!,
                                     range: linkRange)
        
        learnMoreTextView.attributedText = learnMoreString
        learnMoreTextView.font = UIFont.systemFont(ofSize: 14)
//        learnMoreTextView.font = UIFont(name: "CoolSans-Medium", size: 14)
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        return true
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
