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

class ProgressView: UIView {
    let circle: UIView
    let progressCircle: CAShapeLayer
    let lineWidth:CGFloat = 5.0
    let strokeColor = UIColor.red
    
    override init(frame: CGRect) {
        progressCircle = CAShapeLayer ()
        circle = UIView(frame: frame)
        
        circle.layoutIfNeeded()
        
        super.init(frame: frame)
        
        configureCircle()
        self.addSubview(circle)
    }
    
    required init?(coder aDecoder: NSCoder) {
        progressCircle = CAShapeLayer ()
        circle = UIView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
        
        super.init(coder: aDecoder)
        //        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        configureCircle()
        addSubview(circle)
    }
    
    func configureCircle() {
        let centerPoint = CGPoint (x: circle.bounds.width / 2, y: circle.bounds.width / 2)
        let circleRadius : CGFloat = circle.bounds.width / 2 - (lineWidth / 2)
        
        let circlePath = UIBezierPath(arcCenter: centerPoint, radius: circleRadius, startAngle: CGFloat(-0.5 * .pi), endAngle: CGFloat(1.5 * .pi), clockwise: true    )
        circlePath.lineCapStyle = .round
        
        progressCircle.path = circlePath.cgPath
        progressCircle.strokeColor = strokeColor.cgColor
        progressCircle.fillColor = UIColor.clear.cgColor
        progressCircle.lineWidth = lineWidth
        progressCircle.strokeStart = 0
        progressCircle.strokeEnd = 0.0
        circle.layer.addSublayer(progressCircle)
    }
    
    func play(duration: Double) {
        progressCircle.strokeEnd = 0.0
        progressCircle.speed = 1.0

        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 1.0
        animation.duration = duration
        animation.fillMode = kCAFillModeForwards
        animation.isRemovedOnCompletion = false
        progressCircle.add(animation, forKey: "ani")
    }
    
    func stop() {
        progressCircle.speed = 0.0
    }
    
    func reset() {
        progressCircle.removeAllAnimations()
        progressCircle.speed = 1.0
        progressCircle.strokeEnd = 0.0
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
