//import SwiftUI
//import Metal
//import MetalKit
//
//struct MetalView: View {
//    typealias Operation = (MTLCommandBuffer, MTLTexture, MTLTexture) -> Void
//
//    let operation: Operation
//
//    var body: some View {
//        MetalViewRepresentable(operation: operation)
//    }
//}
//
//private struct MetalViewRepresentable: UIViewRepresentable {
//    typealias Operation = MetalView.Operation
//
//    let operation: Operation
//
//    func makeUIView(context: Context) -> MTKView {
//        let view = MTKView()
//        view.enableSetNeedsDisplay = true
//        view.isPaused = true
//        view.framebufferOnly = false
//        view.delegate = context.coordinator
//        return view
//    }
//
//    func updateUIView(_ uiView: MTKView, context: Context) {
//        context.coordinator.operation = operation
//        uiView.setNeedsDisplay()
//    }
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(operation: operation)
//    }
//
//    class Coordinator: NSObject, MTKViewDelegate {
//        var operation: Operation
//
//        init(operation: @escaping Operation) {
//            self.operation = operation
//        }
//
//        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
//
//        func draw(in view: MTKView) {
//            guard let device = view.device,
//                  let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer(),
//                  let sourceTexture = view.currentDrawable?.texture,
//                  let descriptor = MTLTextureDescriptor.texture2DDescriptor(
//                    pixelFormat: sourceTexture.pixelFormat,
//                    width: sourceTexture.width,
//                    height: sourceTexture.height,
//                    mipmapped: false
//                  ),
//                  let destinationTexture = device.makeTexture(descriptor: descriptor) else {
//                return
//            }
//
//            operation(commandBuffer, sourceTexture, destinationTexture)
//
//            if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
//                blitEncoder.copy(
//                    from: destinationTexture,
//                    sourceSlice: 0,
//                    sourceLevel: 0,
//                    sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
//                    sourceSize: MTLSize(
//                        width: destinationTexture.width,
//                        height: destinationTexture.height,
//                        depth: 1
//                    ),
//                    to: sourceTexture,
//                    destinationSlice: 0,
//                    destinationLevel: 0,
//                    destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
//                )
//                blitEncoder.endEncoding()
//            }
//
//            if let drawable = view.currentDrawable {
//                commandBuffer.present(drawable)
//            }
//
//            commandBuffer.commit()
//        }
//    }
//}
