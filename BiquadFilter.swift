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

import SceneKit

class BiquadFilter {
    var val = SCNVector3()
    
    var inst: [BiquadFilterInstance] = [BiquadFilterInstance]()
    
    init (_ Fc: Double, dimensions: Int){
        for _ in 0..<dimensions {
            inst.append(BiquadFilterInstance(Fc))
        }
    }
    
    func update(_ floatIn: Float) -> Float {
        guard inst.count == 1 else {
            print("Animation BiquadFilter set up incorrectly")
            return 0
        }
        return inst[0].process(Double(floatIn))
    }
    
    func update(_ vectorIn: SCNVector3) -> SCNVector3 {
        guard inst.count == 3 else {
            print("BiquadFilter set up incorrectly")
            return SCNVector3Zero
        }
        var val = SCNVector3()
        val.x = inst[0].process(Double(vectorIn.x))
        val.y = inst[1].process(Double(vectorIn.y))
        val.z = inst[2].process(Double(vectorIn.z))
        
        return val;
    }
}

class BiquadFilterInstance {
    var a0, a1, a2, b1, b2: Double
    var Fc=0.5, Q=0.707
    var z1:Double=0.0, z2:Double=0.0
    
    init (_ fc: Double) {
        Fc = fc
        
        // calcBiquad (in Swift, can't call from init unless all vars are defined first)
        let K = tan(.pi * Fc)
        let norm = 1 / (1 + K / Q + K * K)
        a0 = K * K * norm
        a1 = 2 * a0
        a2 = a0
        b1 = 2 * (K * K - 1) * norm
        b2 = (1 - K / Q + K * K) * norm
        
    }
    
    func process(_ valueIn: Double) -> Float {
        let out = valueIn * a0 + z1
        z1 = valueIn * a1 + z2 - b1 * out
        z2 = valueIn * a2 - b2 * out
        return Float(out)
    }
}

