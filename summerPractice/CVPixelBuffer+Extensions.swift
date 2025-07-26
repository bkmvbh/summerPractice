import CoreVideo

extension CVPixelBuffer {
    var pixelFormatName: String {
        let p = CVPixelBufferGetPixelFormatType(self)
        switch p {
        case kCVPixelFormatType_32BGRA: return "BGRA"
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: return "NV12"
        default: return "Unknown(\(p))"
        }
    }
    
    func copy() -> CVPixelBuffer? {
        var copyBuffer: CVPixelBuffer?
        
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: CVPixelBufferGetPixelFormatType(self),
            kCVPixelBufferWidthKey: CVPixelBufferGetWidth(self),
            kCVPixelBufferHeightKey: CVPixelBufferGetHeight(self)
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetWidth(self),
            CVPixelBufferGetHeight(self),
            CVPixelBufferGetPixelFormatType(self),
            attributes as CFDictionary,
            &copyBuffer
        )
        
        guard status == kCVReturnSuccess, let output = copyBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(self, .readOnly)
        CVPixelBufferLockBaseAddress(output, [])
        defer {
            CVPixelBufferUnlockBaseAddress(output, [])
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
        }
        
        if let source = CVPixelBufferGetBaseAddress(self),
           let dest = CVPixelBufferGetBaseAddress(output) {
            let bufferSize = CVPixelBufferGetDataSize(self)
            memcpy(dest, source, bufferSize)
        }
        
        return output
    }
}
