import Metal
import MetalKit
import simd

//extension CommonMetalEngine {
//    public func simpleCircleDetection(
//        data: Data,
//        minDiameter: Int = 10,
//        maxDiameter: Int = 100,
//        threshold: Float = 0.5,
//        maxCircles: Int = 100
//    ) async throws -> CircleDetectionResult {
//        guard let width = self.textureWidth, let height = self.textureHeight else {
//            throw MetalEngineError.generalError(message: "Input texture dimensions not set")
//        }
//        
//        let texture = try self.createTexture(data: data, width: width, height: height)
//        
//        let grayscaleTexture = try self.grayscale(texture: texture)
//        
//        var textureData = [UInt8](repeating: 0, count: width * height)
//        grayscaleTexture.getBytes(&textureData,
//                                  bytesPerRow: width,
//                                  from: MTLRegionMake2D(0, 0, width, height),
//                                  mipmapLevel: 0)
//                                  
//        var circles: [DetectedCircle] = []
//        let thresholdValue = UInt8(threshold * 255)
//        
//        for r in (minDiameter / 2)...(maxDiameter / 2) {
//            for y in 0..<(height - r * 2) {
//                for x in 0..<(width - r * 2) {
//                    var score = 0
//                    for theta in 0..<360 {
//                        let a = x + r + Int(Float(r) * cos(Float(theta) * .pi / 180.0))
//                        let b = y + r + Int(Float(r) * sin(Float(theta) * .pi / 180.0))
//                        
//                        if a >= 0 && a < width && b >= 0 && b < height {
//                            if textureData[b * width + a] > thresholdValue {
//                                score += 1
//                            }
//                        }
//                    }
//                    
//                    if Float(score) / 360.0 > 0.7 { // Confidence threshold
//                        let newCircle = DetectedCircle(x: Float(x + r), y: Float(y + r), diameter: Float(r * 2), confidence: Float(score) / 360.0)
//                        
//                        var isOverlapping = false
//                        for existingCircle in circles {
//                            if simd.distance(newCircle.position, existingCircle.position) < newCircle.radius + existingCircle.radius {
//                                isOverlapping = true
//                                break
//                            }
//                        }
//                        
//                        if !isOverlapping {
//                            circles.append(newCircle)
//                            if circles.count >= maxCircles {
//                                return .init(texture: texture, width: width, height: height, detectedCircles: circles)
//                            }
//                        }
//                    }
//                }
//            }
//        }
//        
//        return .init(texture: texture, width: width, height: height, detectedCircles: circles)
//    }
//    
//    internal func grayscale(texture: MTLTexture) throws -> MTLTexture {
//        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm,
//                                                                  width: texture.width,
//                                                                  height: texture.height,
//                                                                  mipmapped: false)
//        descriptor.usage = [.shaderRead, .shaderWrite]
//        guard let grayscaleTexture = self.engine?.device.makeTexture(descriptor: descriptor) else {
//            throw MetalEngineError.generalError(message: "Failed to create grayscale texture")
//        }
//        
//        guard let commandBuffer = self.engine?.commandQueue.makeCommandBuffer(),
//              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
//            throw MetalEngineError.commandBufferCreationFailed
//        }
//        
//        let pipelineState = try self.engine!.initializePipeline(name: "grayscale")
//        
//        commandEncoder.setComputePipelineState(pipelineState)
//        commandEncoder.setTexture(texture, index: 0)
//        commandEncoder.setTexture(grayscaleTexture, index: 1)
//        
//        let threadgroupSize = self.engine!.calculateOptimalThreadgroupSize(pipelineState: pipelineState,
//                                                                           outputWidth: texture.width,
//                                                                           outputHeight: texture.height)
//        let threadgroupCount = MTLSize(width: (texture.width + threadgroupSize.width - 1) / threadgroupSize.width,
//                                       height: (texture.height + threadgroupSize.height - 1) / threadgroupSize.height,
//                                       depth: 1)
//        
//        commandEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
//        commandEncoder.endEncoding()
//        
//        commandBuffer.commit()
//        commandBuffer.waitUntilCompleted()
//        
//        return grayscaleTexture
//    }
//    
//    internal func createTexture(data: Data, width: Int, height: Int) throws -> MTLTexture {
//        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
//                                                                  width: width,
//                                                                  height: height,
//                                                                  mipmapped: false)
//        descriptor.usage = [.shaderRead, .shaderWrite]
//        guard let texture = self.engine?.device.makeTexture(descriptor: descriptor) else {
//            throw MetalEngineError.generalError(message: "Failed to create texture")
//        }
//        
//        let region = MTLRegionMake2D(0, 0, width, height)
//        texture.replace(region: region,
//                        mipmapLevel: 0,
//                        withBytes: (data as NSData).bytes,
//                        bytesPerRow: width * 4)
//                        
//        return texture
//    }
//} 
