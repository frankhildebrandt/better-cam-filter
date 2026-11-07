import CoreMediaIO
import Foundation

/// All access is confined to the capture engine's serial frame queue.
final class VirtualCameraOutput {
    var configuration = OutputConfiguration()
    private var device: CMIODeviceID?
    private var stream: CMIOStreamID?
    private var bufferQueue: CMSimpleQueue?
    private var nextDiscovery = Date.distantPast
    private var lastEnqueued: TimeInterval = 0

    func send(_ sample: CMSampleBuffer) throws -> Bool {
        if bufferQueue == nil {
            guard Date() >= nextDiscovery else { return false }
            nextDiscovery = Date().addingTimeInterval(2)
            try connect()
        }
        guard let bufferQueue else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        guard CMSimpleQueueGetCount(bufferQueue) < CMSimpleQueueGetCapacity(bufferQueue) else {
            if now - lastEnqueued > 1 {
                disconnect()
                return false
            }
            return true
        }
        let retained = Unmanaged.passRetained(sample)
        let status = CMSimpleQueueEnqueue(bufferQueue, element: retained.toOpaque())
        if status != noErr {
            retained.release()
            disconnect()
            try VideoBuffers.check(status)
        }
        lastEnqueued = now
        return true
    }

    private func connect() throws {
        let devices = try CMIOProperties.objects(CMIOObjectID(kCMIOObjectSystemObject),
                                                 selector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices))
        for candidate in devices {
            guard let uid = try? CMIOProperties.string(candidate, selector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceUID)),
                  uid.caseInsensitiveCompare(CameraConfiguration.deviceID.uuidString) == .orderedSame else { continue }
            let streams = try CMIOProperties.objects(candidate, selector: CMIOObjectPropertySelector(kCMIODevicePropertyStreams))
            for candidateStream in streams {
                let direction = try CMIOProperties.uint32(candidateStream, selector: CMIOObjectPropertySelector(kCMIOStreamPropertyDirection))
                guard direction == 0 else { continue }
                try CMIOProperties.configure(candidateStream, for: configuration)
                var queue: Unmanaged<CMSimpleQueue>?
                try VideoBuffers.check(CMIOStreamCopyBufferQueue(candidateStream, { _, _, _ in }, nil, &queue))
                let ownedQueue = queue?.takeRetainedValue()
                try VideoBuffers.check(CMIODeviceStartStream(candidate, candidateStream))
                device = candidate
                stream = candidateStream
                bufferQueue = ownedQueue
                return
            }
        }
    }

    func disconnect() {
        if let device, let stream, CMIODeviceStopStream(device, stream) == noErr, let bufferQueue {
            // Once the consumer stops, release samples still waiting in the pointer queue.
            while let pointer = CMSimpleQueueDequeue(bufferQueue) {
                Unmanaged<CMSampleBuffer>.fromOpaque(pointer).release()
            }
        }
        bufferQueue = nil
        stream = nil
        device = nil
        nextDiscovery = .distantPast
        lastEnqueued = 0
    }
}
