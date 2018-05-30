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
import Metal

enum Radius: Float {
    case small = 0.006
    case medium = 0.011
    case large = 0.020
}


class LineGeometry : SCNGeometry {
    var vectors = [SCNVector3]()
    var sides = [Float]()
    var width: Float = 0
    var lengths = [Float]()
    var endCapPosition: Float = 0
    
    /// Code currently all happens in init because I can't call init'ed functions until super.init is called, and you can only call one super.init.  I am relying on the built-in init(sources:elements:) convenience method for drawing the geometry
    convenience init(vectors: [SCNVector3], sides: [Float], width: Float, lengths: [Float], endCapPosition: Float) {
        var indices = [Int32]()
        
        // Loop through center points
        for i in 0..<vectors.count {
            indices.append(Int32(i))
        }
        
        let source = SCNGeometrySource(vertices: vectors)
        let indexData = Data(bytes: indices,
                             count: indices.count * MemoryLayout<Int32>.size)
        
        // Now without runtime error
        let element = SCNGeometryElement(data: indexData,
                                         primitiveType: .triangleStrip,
                                         primitiveCount: indices.count - 2,
                                         bytesPerIndex: MemoryLayout<Int32>.size)
        
//        self.init()
        self.init(sources: [source], elements: [element])
        self.vectors = vectors
        self.sides = sides
        self.width = width
        self.lengths = lengths
        self.endCapPosition = endCapPosition
        
        self.wantsAdaptiveSubdivision = true
        
        let lineProgram = SCNProgram()
        lineProgram.vertexFunctionName = "basic_vertex"
        lineProgram.fragmentFunctionName = "basic_fragment"
        program = lineProgram
        program?.isOpaque = false
        
        let endCapImage = UIImage(named: "linecap")!
        let endCapTexture = SCNMaterialProperty(contents: endCapImage)
        self.setValue(endCapTexture, forKey: "endCapTexture")
        
//        let borderImage = UIImage(named: "texture")!
//        let borderTexture = SCNMaterialProperty(contents: borderImage)
//        self.setValue(borderTexture, forKey: "borderTexture")

        
//        let resolution = CGPoint(x: UIScreen.main.bounds.size.width, y: UIScreen.main.bounds.size.height)
//        let color = UIColor.white.cgColor

//        self.setValue(resolution, forKey:"resolution")
//        self.setValue(color, forKey: "color")
        
//        lineProgram.handleBinding(ofBufferNamed: "myUniforms", frequency: .perShadable, handler: { (bufferStream, renderedNode, geometry, renderer) in
//            var resolution = float2(Float(UIScreen.main.bounds.size.width), Float(UIScreen.main.bounds.size.height))
//            var color = float4(1,1,1,1)
//
//            bufferStream.writeBytes(&resolution, count: MemoryLayout<Float>.size*2)
//            bufferStream.writeBytes(&color, count: MemoryLayout<Float>.size*4)
//        })
        
        program?.handleBinding(ofBufferNamed: "vertices", frequency: .perShadable, handler: { (bufferStream, renderedNode, geometry, renderer) in
            if let line = renderedNode.geometry as? LineGeometry {
                var programVertices = line.generateVertexData()
                bufferStream.writeBytes(&programVertices, count: MemoryLayout<MyVertex>.size*programVertices.count)
            }
        })
        

    }
    
    
//    deinit {
//        print("Deinit line geometry")
//    }
    
    func generateVertexData()->[MyVertex] {
        var vertexArray = [MyVertex]()
        var vertex: MyVertex = MyVertex()
    
        for i in 0..<vectors.count {
            vertex.position = float3(x: vectors[i].x, y:vectors[i].y, z: vectors[i].z)
            vertex.vertexCount = Int32(vectors.count)
//            vertex.previous = stroke.mPrevious[i]
//            vertex.next = stroke.mNext[i]
            vertex.side = sides[i]
            vertex.width = width
            vertex.length = lengths[i]
            vertex.endCap = endCapPosition
            vertex.color = float4(1,1,1,1)
//            vertex.counters = stroke.mCounters[i]
            vertex.resolution = float2(Float(UIScreen.main.bounds.size.width), Float(UIScreen.main.bounds.size.height))

            vertexArray.append(vertex)
        }

        return vertexArray
    }
}
