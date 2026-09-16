import MetalKit
import SwiftUI

/// Swift/Metal uniform layout: only 16-byte vectors, shared with VisualWorldInstallation.metal.
nonisolated struct VisualWorldUniforms: Equatable {
    var viewport = SIMD4<Float>(1, 1, 0, 0)
    var motion = SIMD4<Float>(repeating: 0)
    var sound = SIMD4<Float>(repeating: 0)
    var character = SIMD4<Float>(0.5, 0.5, 0.5, 0.5)
    var tonal = SIMD4<Float>(0.5, 0, 0, 0)
    var primary = SIMD4<Float>(0.23, 0.4, 1, 1)
    var secondary = SIMD4<Float>(0.85, 0.12, 0.55, 1)
    var accent = SIMD4<Float>(0.4, 0.9, 1, 1)
    var material = SIMD4<Float>(0.5, 0.5, 0.5, 0.6)
    var layout = SIMD4<Float>(0, 1, 2, 3)
    var spatial = SIMD4<Float>(repeating: 0)
    var band0 = SIMD4<Float>(repeating: 0)
    var band1 = SIMD4<Float>(repeating: 0)
    var band2 = SIMD4<Float>(repeating: 0)
    var band3 = SIMD4<Float>(repeating: 0)
    var band4 = SIMD4<Float>(repeating: 0)
    var band5 = SIMD4<Float>(repeating: 0)
}

struct VisualWorldMetalView: UIViewRepresentable {
    var uniforms: VisualWorldUniforms
    var active: Bool
    var lowPower: Bool
    var frameInterval: Double
    var onFailure: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.isOpaque = true
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        if let renderer = VisualWorldMetalRenderer(view: view) {
            context.coordinator.renderer = renderer
            view.delegate = renderer
        } else {
            DispatchQueue.main.async { onFailure() }
        }
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        renderer.uniforms = uniforms
        renderer.lowPower = lowPower
        renderer.animateTransitions = active
        renderer.frameInterval = frameInterval
        // SwiftUI's display timeline is the only clock; MTKView doesn't run a second display link.
        if active || renderer.needsStaticFrame || renderer.lastUniforms != uniforms {
            view.draw()
        }
    }

    static func dismantleUIView(_ view: MTKView, coordinator: Coordinator) {
        view.isPaused = true
        view.delegate = nil
        coordinator.renderer = nil
    }

    final class Coordinator {
        var renderer: VisualWorldMetalRenderer?
    }
}

@MainActor
final class VisualWorldMetalRenderer: NSObject, MTKViewDelegate {
    var uniforms = VisualWorldUniforms()
    var lowPower = false
    var animateTransitions = true
    var frameInterval = 1.0 / 30
    private var lastSubmission = 0.0
    var needsStaticFrame = true
    var lastUniforms: VisualWorldUniforms?
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let scenePipeline: MTLRenderPipelineState
    private let compositePipeline: MTLRenderPipelineState
    private var sceneTexture: MTLTexture?
    private var lastSize = CGSize.zero
    // Do not block the main thread when the GPU is behind.
    private var displayed: VisualWorldUniforms?
    private var previousFrameTime = ProcessInfo.processInfo.systemUptime
    private let inFlight = DispatchSemaphore(value: 2)

    init?(view: MTKView) {
        guard let device = view.device, let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let vertex = library.makeFunction(name: "visualWorldVertex"),
              let scene = library.makeFunction(name: "visualWorldFragment"),
              let composite = library.makeFunction(name: "visualWorldComposite") else { return nil }
        func pipeline(_ fragment: MTLFunction, _ format: MTLPixelFormat) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = format
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }
        do {
            scenePipeline = try pipeline(scene, .rgba16Float)
            compositePipeline = try pipeline(composite, view.colorPixelFormat)
        } catch { return nil }
        self.device = device; self.queue = queue
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        needsStaticFrame = true
        view.setNeedsDisplay()
    }

    func draw(in view: MTKView) {
        let submissionTime = ProcessInfo.processInfo.systemUptime
        // Audio/metadata observation can also update SwiftUI; it must not exceed the frame budget.
        if animateTransitions && !needsStaticFrame && submissionTime - lastSubmission < frameInterval * 0.9 { return }
        guard view.drawableSize.width > 0, view.drawableSize.height > 0,
              inFlight.wait(timeout: .now()) == .success else { return }
        let semaphore = inFlight
        guard let drawable = view.currentDrawable, let finalPass = view.currentRenderPassDescriptor,
              let command = queue.makeCommandBuffer() else { semaphore.signal(); return }
        let maxPixels: Double = lowPower ? 450_000 : 900_000
        let scale = min(lowPower ? 0.55 : 0.75, sqrt(maxPixels / (view.drawableSize.width * view.drawableSize.height)))
        let size = CGSize(width: max(1, floor(view.drawableSize.width * scale)),
                          height: max(1, floor(view.drawableSize.height * scale)))
        if size != lastSize || sceneTexture == nil {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
                width: Int(size.width), height: Int(size.height), mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead]
            descriptor.storageMode = .private
            sceneTexture = device.makeTexture(descriptor: descriptor)
            lastSize = size
        }
        guard let sceneTexture else { semaphore.signal(); return }
        var frame = uniforms
        let now = ProcessInfo.processInfo.systemUptime
        let blend = Float(1 - exp(-min(max(now - previousFrameTime, 0), 0.1) / 0.7))
        previousFrameTime = now
        if animateTransitions, let old = displayed {
            frame.primary = old.primary + (frame.primary - old.primary) * blend
            frame.secondary = old.secondary + (frame.secondary - old.secondary) * blend
            frame.accent = old.accent + (frame.accent - old.accent) * blend
            for i in 0..<4 {
                let difference = (frame.layout[i] - old.layout[i]).remainder(dividingBy: 2 * .pi)
                frame.layout[i] = old.layout[i] + difference * blend
            }
        }
        displayed = frame
        frame.viewport.x = Float(size.width); frame.viewport.y = Float(size.height)
        frame.tonal.w = lowPower ? 1 : 0
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = sceneTexture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { semaphore.signal(); return }
        encoder.setRenderPipelineState(scenePipeline)
        encoder.setFragmentBytes(&frame, length: MemoryLayout<VisualWorldUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        guard let composite = command.makeRenderCommandEncoder(descriptor: finalPass) else { semaphore.signal(); return }
        composite.setRenderPipelineState(compositePipeline)
        composite.setFragmentTexture(sceneTexture, index: 0)
        composite.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        composite.endEncoding()
        command.addCompletedHandler { _ in semaphore.signal() }
        command.present(drawable)
        command.commit()
        lastSubmission = submissionTime
        needsStaticFrame = false
        lastUniforms = uniforms
    }
}
