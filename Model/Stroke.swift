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

import ARKit
import FirebaseDatabase

final class Stroke: NSObject, NSCopying, FBModel {
    var points = [SCNVector3]()
    
    var drawnLocally = true
    
    public var mTaperLookup = [Float]()
    
    public var mTapperPoints = Int(0)
    
    var mTapperSlope = Float(0)
    
    var lineWidth = Radius.medium.rawValue
    
    var anchor: ARAnchor?
    var node: SCNNode?
    var touchStart: CGPoint = CGPoint.zero
    
    var mLineWidth: Float = 0
    
    var positionsVec3 = [SCNVector3]()
    var mSide = [Float]()
    var mLength = [Float]()
    
    let smoothingCount = 1500
    let biquadFilter = BiquadFilter(0.07, dimensions: 3)
    let animationFilter = BiquadFilter(0.025, dimensions: 1)
    var totalLength: Float = 0
    var animatedLength: Float = 0

    var fbReference: DatabaseReference?
    var creatorUid: String?
    var previousPoints:  [String: [String: NSNumber]]? = nil
    
    public func size() -> Int {
        return points.count
    }
    
    func updateAnimatedStroke() -> Bool {
        var renderNeedsUpdate = false;
        if(!drawnLocally) {
            let previousLength = animatedLength
            animatedLength = animationFilter.update(totalLength)
            
            if(abs(animatedLength - previousLength) > 0.001){
                renderNeedsUpdate = true
            }
        }
        
        return renderNeedsUpdate
    }
    
    deinit {
        print("Stroke deinit")
    }


    
    public func add( point: SCNVector3)->Bool {
        let s = points.count
        
        // Filter the point
        let p = biquadFilter.update(point)
        
        // Check distance, and only add if moved far enough
        if(s > 0){
            let lastPoint = points[s - 1];
            
            let result = point.distance(to: lastPoint)
            
            if result < lineWidth / 10 {
                return false
            }
        }

//        if(points.count <= 1){
//            for _ in 0..<smoothingCount {
//                p = biquadFilter.update(point)
//            }
//        }
        

        totalLength += points[points.count-1].distance(to: p)

        // Add the point
        points.append(p)
        

        
        // Cleanup vertices that are redundant
        if(s > 3) {
            let angle = calculateAngle(index: s-2)
            // Remove points that have very low angle change
            if (angle < 0.05) {
                points.remove(at: (s - 2))
            } else {
                subdivideSection(s: s - 3, maxAngle: 0.3, iteration: 0);
            }
        }
        
        prepareLine()
        
        return true
    }
    
    
    func scaleVec(vec: SCNVector3, factor: Float) -> SCNVector3{
        let sX = vec.x * factor
        let sY = vec.y * factor
        let sZ = vec.z * factor
        
        return SCNVector3(sX, sY, sZ)
        
    }
    
    
    func addVecs(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        let x = lhs.x + rhs.x
        let y = lhs.y + rhs.y
        let z = lhs.z + rhs.z
        
        return SCNVector3(x, y, z)
    }
    
    func normalizeVec(vec: SCNVector3) -> SCNVector3 {
        let x = vec.x
        let y = vec.y
        let z = vec.z
        
        let sqLen = x*x + y*y + z*z
        let len = sqLen.squareRoot()
        
        // zero-div may occur.
        return SCNVector3(x / len, y / len, z / len)
    }
    
    func subVecs(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        let x = lhs.x - rhs.x;
        let y = lhs.y - rhs.y;
        let z = lhs.z - rhs.z;
        return SCNVector3(x, y, z);
    }
    
    func calcAngle(n1: SCNVector3, n2: SCNVector3) -> Float {
        
        let xx = n1.y*n2.z - n1.z*n2.y;
        let yy = n1.z*n2.x - n1.x*n2.z;
        let zz = n1.x*n2.y - n1.y*n2.x;
        let cross = Float(xx*xx + yy*yy + zz*zz).squareRoot()
        
        let dot = n1.x*n2.x + n1.y*n2.y + n1.z*n2.z
        
        return abs(atan2(cross, dot))
        
    }
    
    func calculateAngle(index : Int) -> Float {
        let p1 = points[index-1]
        let p2 = points[index]
        let p3 = points[index+1]
        
        var x = p2.x - p1.x;
        var y = p2.y - p1.y;
        var z = p2.z - p1.z;
        let n1 = SCNVector3(x, y, z);
        
        x = p3.x - p2.x;
        y = p3.y - p2.y;
        z = p3.z - p2.z;
        let n2 = SCNVector3(x, y, z);
        
        let xx = n1.y*n2.z - n1.z*n2.y;
        let yy = n1.z*n2.x - n1.x*n2.z;
        let zz = n1.x*n2.y - n1.y*n2.x;
        let cross = Float(xx*xx + yy*yy + zz*zz).squareRoot()
        
        let dot = n1.x*n2.x + n1.y*n2.y + n1.z*n2.z
        
        return abs(atan2(cross, dot))
        
    }
    
    
    
    func subdivideSection(s: Int, maxAngle: Float, iteration : Int){
        
        if iteration == 6 {
            return
        }
        
        let p1 = points[s]
        let p2 = points[s + 1]
        let p3 = points[s + 2]
        
        var n1 = subVecs(lhs: p2, rhs: p1)
        var n2 = subVecs(lhs: p3, rhs: p2)
        
        let angle = calcAngle(n1: n1, n2: n2)
        
        // If angle is too big, add points
        if(angle > maxAngle){
            
            n1 = scaleVec(vec: n1, factor: 0.5)
            n2 = scaleVec(vec: n2, factor: 0.5)
            n1 = addVecs(lhs: n1, rhs: p1)
            n2 = addVecs(lhs: n2, rhs: p2)
            
            points.insert(n1, at: s + 1 )
            points.insert(n2, at: s + 3 )
            
            subdivideSection(s: s+2, maxAngle: maxAngle, iteration: iteration+1)
            subdivideSection(s: s, maxAngle: maxAngle, iteration: iteration+1)
        }
    }
    
    
    public func get(i: Int) -> SCNVector3 {
        return points[i]
    }
    
    
    func setTapper(slope: Float, numPoints: Int) {
        if mTapperSlope != slope && numPoints != mTapperPoints {
            mTapperSlope = slope
            mTapperPoints = numPoints
            
            var v = Float(1.0)
            for i in (0 ... numPoints - 1).reversed() {
                v *= mTapperSlope;
                mTaperLookup[i] = v;
            }
        }
    }
    
    public func getLineWidth() -> Float {
        return lineWidth
    }
    
    
    func prepareLine() {
        resetMemory()
        
        let lineSize = size();
        let mLineWidthMax = getLineWidth()
        
        var lengthAtPoint: Float = 0
        
        if totalLength <= 0 {
            for i in 1..<lineSize {
                totalLength += points[i-1].distance(to: points[i])
            }
        }
        
        var ii = 0
        for i in 0...lineSize {
            
            var iGood = i
            if iGood < 0 {
                iGood = 0
            }
            if iGood >= lineSize {
                iGood = lineSize - 1
            }
            
            let i_m_1 = (iGood - 1) < 0 ? iGood : iGood - 1
            
            let current = get(i:iGood)
            let previous = get(i:i_m_1)
            
            if (i < mTapperPoints) {
                mLineWidth = mLineWidthMax * mTaperLookup[i]
            } else if (i > lineSize - mTapperPoints) {
                mLineWidth = mLineWidthMax * mTaperLookup[lineSize - i]
            } else {
                mLineWidth = getLineWidth()
            }
            
            lengthAtPoint += previous.distance(to: current)
//            print("Length so far: \(lengthAtPoint)")
            
            mLineWidth = max(0, min(mLineWidthMax, mLineWidth))
            
            ii += 1
            setMemory(index:ii, pos:current, side:1.0, length: lengthAtPoint)
            ii += 1
            setMemory(index:ii, pos:current, side:-1.0, length: lengthAtPoint)
        }
    }
    
    func resetMemory() {
        mSide.removeAll(keepingCapacity: true)
        mLength.removeAll(keepingCapacity: true)
        totalLength = 0
        mLineWidth = 0
        positionsVec3.removeAll(keepingCapacity: true)
    }
   
    func setMemory(index: Int, pos: SCNVector3, side: Float, length: Float) {
        positionsVec3.append(pos)
        mLength.append(length)

//        mNext.append(float3(next.x, next.y, next.z))
//        mPrevious.append(float3(prev.x, prev.y, prev.z))

//        mCounters.append(counter)
        mSide.append(side)
    }
    
    func cleanup() {
        resetMemory()
        points.removeAll()
        node?.removeFromParentNode()
        node = nil
        anchor = nil
        mTaperLookup.removeAll()
        mTapperPoints = 0
        mTapperSlope = 0
        lineWidth = 0
        creatorUid = nil
        touchStart = .zero
        fbReference = nil
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        let strokeCopy = Stroke()
        strokeCopy.points = points.map{ (pt) in
            return SCNVector3Make(pt.x, pt.y, pt.z)
        }
        strokeCopy.mTaperLookup = mTaperLookup
        strokeCopy.mTapperPoints = mTapperPoints
        strokeCopy.mTapperSlope = mTapperSlope
        strokeCopy.lineWidth = lineWidth
        strokeCopy.creatorUid = creatorUid
        strokeCopy.node = node?.copy() as? SCNNode
        strokeCopy.anchor = anchor?.copy() as? ARAnchor
        strokeCopy.touchStart = touchStart
        strokeCopy.mLineWidth = mLineWidth
        strokeCopy.mSide = mSide
        strokeCopy.mLength = mLength

        // strokeCopy.fbReference is not copied
        
        return strokeCopy
    }
    
    
    // MARK: - FBModel Utility Methods
    
    static func from(_ dictionary: [String: Any?]) -> Stroke? {
        var newStroke: Stroke?
        if let fbPoints = dictionary[FBKey.val(.points)] as? [[String: NSNumber]],
            let lineWidth = dictionary[FBKey.val(.lineWidth)] as? NSNumber,
            let creator = dictionary[FBKey.val(.creator)] as? String {
            
            let stroke = Stroke()
            
            var anchorTransform = matrix_float4x4(1)
            
            if let firstPoint = fbPoints.first {
                let firstPointCoord = SCNVector3Make((firstPoint["x"]?.floatValue)!,
                                                     (firstPoint["y"]?.floatValue)!,
                                                     (firstPoint["z"]?.floatValue)!)
                
                anchorTransform.columns.3.x = firstPointCoord.x
                anchorTransform.columns.3.y = firstPointCoord.y
                anchorTransform.columns.3.z = firstPointCoord.z

                var points = [SCNVector3]()
                for point in fbPoints {
                    if let x = point["x"], let y = point["y"], let z = point["z"] {
                        let vector = SCNVector3Make(x.floatValue - firstPointCoord.x,
                                                    y.floatValue - firstPointCoord.y,
                                                    z.floatValue - firstPointCoord.z)
                        points.append(vector)
                    }
                }
                stroke.lineWidth = lineWidth.floatValue
                stroke.points = points
                stroke.creatorUid = creator
                
                stroke.anchor = ARAnchor(transform: anchorTransform)
                
                newStroke = stroke
            }
        }
        return newStroke
    }
    
    func dictionaryValue() -> [String : Any?] {
        guard let node = node else {
            print("Stroke:dictionaryValue: There was a problem converting stroke \(self) into dictionary values")
            return [String: Any?]()
        }

        var dictionary = [String: Any?]()
        var pointsDictionary = [String: [String: NSNumber]]()
        
//        print("Transform for stroke: \(String(describing: anchor?.transform))")

        // world space math should be incorporated into the loop below
        var pointObj = [String: NSNumber]()

        for (i,point) in points.enumerated() {
            pointObj["x"] = NSNumber(value: point.x + node.position.x)
            pointObj["y"] = NSNumber(value: point.y + node.position.y)
            pointObj["z"] = NSNumber(value: point.z + node.position.z)
            
            pointsDictionary[ String(i) ] = pointObj
        }
        dictionary[FBKey.val(.creator)] = creatorUid
        dictionary[FBKey.val(.points)] = pointsDictionary
        dictionary[FBKey.val(.lineWidth)] = NSNumber(value:lineWidth)

        previousPoints = pointsDictionary

        return dictionary
    }
    
    
    /// Dictionary only containing the points that changed since last call
    func pointsUpdateDictionaryValue() -> [String : [String: NSNumber]] {
        guard let node = node else {
            print("Stroke:pointsUpdateDictionaryValue: There was a problem converting stroke \(self) into dictionary values")
            return [String: [String: NSNumber]]()
        }

        var pointsArray = [String: [String: NSNumber]]()
        var fullPointsArray = [String: [String: NSNumber]]()
        
        // world space math should be incorporated into the loop below
        var pointObj = [String: NSNumber]()
        
        for (i, point) in points.enumerated() {
            pointObj["x"] = NSNumber(value: point.x + node.position.x)
            pointObj["y"] = NSNumber(value: point.y + node.position.y)
            pointObj["z"] = NSNumber(value: point.z + node.position.z)
            
            if let previousPoints = previousPoints, previousPoints.count > i, let previousPoint = previousPoints[String(i)] {
                if( pointObj["x"] != previousPoint["x"]
                    || pointObj["y"] != previousPoint["y"]
                    || pointObj["z"] != previousPoint["z"]){
                    
                    pointsArray[ String(i) ] = pointObj
                }
            } else {
                pointsArray[ String(i) ] = pointObj
            }
            fullPointsArray[ String(i) ] = pointObj
        }

        previousPoints = fullPointsArray
        return pointsArray
    }
}

