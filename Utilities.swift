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

/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Utility functions and type extensions used throughout the projects.
*/

import Foundation
import ARKit


// MARK: - AHC Float3 extension
extension SCNVector3{
    func distance(to receiver:SCNVector3) -> Float{
        let xd = receiver.x - self.x
        let yd = receiver.y - self.y
        let zd = receiver.z - self.z
        let distance = Float(sqrt(xd * xd + yd * yd + zd * zd))
        
        if (distance < 0){
            return (distance * -1)
        } else {
            return (distance)
        }
    }
}


// MARK: - Collection extensions
extension Array where Iterator.Element == Float {
	var average: Float? {
		guard !self.isEmpty else {
			return nil
		}
		
		let sum = self.reduce(Float(0)) { current, next in
			return current + next
		}
		return sum / Float(self.count)
	}
}

extension Array where Iterator.Element == float3 {
	var average: float3? {
		guard !self.isEmpty else {
			return nil
		}
  
        let sum = self.reduce(float3(0)) { current, next in
            return current + next
        }
		return sum / Float(self.count)
	}
}

extension Array where Iterator.Element == float4 {
    var average: float4? {
        guard !self.isEmpty else {
            return nil
        }
        
        let sum = self.reduce(float4(0)) { current, next in
            return current + next
        }
        return sum / Float(self.count)
    }
}

extension RangeReplaceableCollection {
	mutating func keepLast(_ elementsToKeep: Int) {
		if count > elementsToKeep {
			self.removeFirst(count - elementsToKeep)
		}
	}
}

// MARK: - SCNNode extension

extension SCNNode {
	
	func setUniformScale(_ scale: Float) {
		self.simdScale = float3(scale, scale, scale)
	}
	
	func renderOnTop(_ enable: Bool) {
		self.renderingOrder = enable ? 2 : 0
		if let geom = self.geometry {
			for material in geom.materials {
				material.readsFromDepthBuffer = enable ? false : true
			}
		}
		for child in self.childNodes {
			child.renderOnTop(enable)
		}
	}
}

// MARK: - float4x4 extensions

extension float4x4 {
    /// Treats matrix as a (right-hand column-major convention) transform matrix
    /// and factors out the translation component of the transform.
    var translation: float3 {
        let translation = self.columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}

// MARK: - CGPoint extensions

extension CGPoint {
	
	init(_ size: CGSize) {
        self.init()
        self.x = size.width
		self.y = size.height
	}
	
	init(_ vector: SCNVector3) {
        self.init()
        self.x = CGFloat(vector.x)
		self.y = CGFloat(vector.y)
	}
	
	func distanceTo(_ point: CGPoint) -> CGFloat {
		return (self - point).length()
	}
	
	func length() -> CGFloat {
		return sqrt(self.x * self.x + self.y * self.y)
	}
	
	func midpoint(_ point: CGPoint) -> CGPoint {
		return (self + point) / 2
	}
    static func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }
    
    static func - (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x - right.x, y: left.y - right.y)
    }
    
    static func += (left: inout CGPoint, right: CGPoint) {
        left = left + right
    }
    
    static func -= (left: inout CGPoint, right: CGPoint) {
        left = left - right
    }
    
    static func / (left: CGPoint, right: CGFloat) -> CGPoint {
        return CGPoint(x: left.x / right, y: left.y / right)
    }
    
    static func * (left: CGPoint, right: CGFloat) -> CGPoint {
        return CGPoint(x: left.x * right, y: left.y * right)
    }
    
    static func /= (left: inout CGPoint, right: CGFloat) {
        left = left / right
    }
    
    static func *= (left: inout CGPoint, right: CGFloat) {
        left = left * right
    }
}

// MARK: - CGSize extensions

extension CGSize {
	init(_ point: CGPoint) {
        self.init()
        self.width = point.x
		self.height = point.y
	}

    static func + (left: CGSize, right: CGSize) -> CGSize {
        return CGSize(width: left.width + right.width, height: left.height + right.height)
    }

    static func - (left: CGSize, right: CGSize) -> CGSize {
        return CGSize(width: left.width - right.width, height: left.height - right.height)
    }

    static func += (left: inout CGSize, right: CGSize) {
        left = left + right
    }

    static func -= (left: inout CGSize, right: CGSize) {
        left = left - right
    }

    static func / (left: CGSize, right: CGFloat) -> CGSize {
        return CGSize(width: left.width / right, height: left.height / right)
    }

    static func * (left: CGSize, right: CGFloat) -> CGSize {
        return CGSize(width: left.width * right, height: left.height * right)
    }

    static func /= (left: inout CGSize, right: CGFloat) {
        left = left / right
    }

    static func *= (left: inout CGSize, right: CGFloat) {
        left = left * right
    }
}

// MARK: - CGRect extensions

extension CGRect {
	var mid: CGPoint {
		return CGPoint(x: midX, y: midY)
	}
}

func rayIntersectionWithHorizontalPlane(rayOrigin: float3, direction: float3, planeY: Float) -> float3? {
	
    let direction = simd_normalize(direction)

    // Special case handling: Check if the ray is horizontal as well.
	if direction.y == 0 {
		if rayOrigin.y == planeY {
			// The ray is horizontal and on the plane, thus all points on the ray intersect with the plane.
			// Therefore we simply return the ray origin.
			return rayOrigin
		} else {
			// The ray is parallel to the plane and never intersects.
			return nil
		}
	}
	
	// The distance from the ray's origin to the intersection point on the plane is:
	//   (pointOnPlane - rayOrigin) dot planeNormal
	//  --------------------------------------------
	//          direction dot planeNormal
	
	// Since we know that horizontal planes have normal (0, 1, 0), we can simplify this to:
	let dist = (planeY - rayOrigin.y) / direction.y

	// Do not return intersections behind the ray's origin.
	if dist < 0 {
		return nil
	}
	
	// Return the intersection point.
	return rayOrigin + (direction * dist)
}

extension UIColor {
    
    // based on  http://www.zombieprototypes.com/?p=210 who looked at some data and did a bunch of curve fitting
    static func colorWithKelvin( kelvin: CGFloat) -> UIColor {
        let k = kelvin < 1000 ? 1000 : ( kelvin > 40000 ? 40000 : kelvin)
        
        func interpolate( value: CGFloat, a: CGFloat, b:CGFloat, c:CGFloat) -> CGFloat {
            return a + b*value + c*log(value)
        }
        
        var red,green,blue: CGFloat
        
        if k < 6600 {
            red = 255
            green = interpolate(value: k/100-2, a: -155.25485562709179, b: -0.44596950469579133, c: 104.49216199393888)
            if k < 2000 {
                blue = 0
            } else {
                blue = interpolate(value: k/100-10, a: -254.76935184120902, b: 0.8274096064007395, c: 115.67994401066147)
            }
        } else {
            red = interpolate( value: k/100-55, a: 351.97690566805693, b: 0.114206453784165, c: -40.25366309332127)
            green = interpolate(value: k/100-50, a: 325.4494125711974, b: 0.07943456536662342, c: -28.0852963507957)
            blue = 255
        }
        
        return UIColor(red: red/255, green: green/255, blue: blue/255, alpha: 1.0)
    }
    
    static func colorByMultiplying( a: UIColor, _ b: UIColor) -> UIColor {
        var ar = CGFloat(0)
        var ab = CGFloat(0)
        var ag = CGFloat(0)
        var aa = CGFloat(0)
        
        var br = CGFloat(0)
        var bb = CGFloat(0)
        var bg = CGFloat(0)
        var ba = CGFloat(0)
        
        if a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa) &&
            b.getRed(&br, green: &bg, blue: &bb, alpha: &ba) {
            return UIColor(red: ar*br, green: ag*bg, blue: ab*bb, alpha: aa*ba)
        } else {
            // Couldn't work.
            return a
        }
        
    }
}
