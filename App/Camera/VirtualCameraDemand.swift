import CoreMediaIO
import Foundation

/// Observes the virtual camera without opening either of its streams.
final class VirtualCameraDemand: @unchecked Sendable {
    private let queue = DispatchQueue(label: "de.bettercam.demand")
    private let onChange: @MainActor @Sendable (Bool) -> Void
    private var observingDevices = false
    private var device: CMIODeviceID?
    private var active = false

    private lazy var devicesChanged: CMIOObjectPropertyListenerBlock = { [weak self] _, _ in
        guard let self, self.observingDevices else { return }
        self.refreshDevice()
    }
    private lazy var demandChanged: CMIOObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.readDemand()
    }

    init(onChange: @escaping @MainActor @Sendable (Bool) -> Void) {
        self.onChange = onChange
    }

    func start() {
        queue.async {
            var address = CMIOProperties.address(CMIOProperties.devicesSelector)
            self.observingDevices = CMIOObjectAddPropertyListenerBlock(
                CMIOProperties.system, &address, self.queue, self.devicesChanged
            ) == noErr
            self.refreshDevice()
        }
    }

    func stop() {
        queue.sync {
            if observingDevices {
                var address = CMIOProperties.address(CMIOProperties.devicesSelector)
                CMIOObjectRemovePropertyListenerBlock(CMIOProperties.system, &address, queue, devicesChanged)
                observingDevices = false
            }
            removeDeviceListener()
        }
    }

    private func refreshDevice() {
        let current = try? CMIOProperties.betterCamDevice()
        if device != current {
            removeDeviceListener()
            if let current {
                var address = CMIOProperties.address(CameraConfiguration.sourceDemandSelector)
                if CMIOObjectAddPropertyListenerBlock(current, &address, queue, demandChanged) == noErr {
                    device = current
                }
            }
        }
        readDemand()
    }

    private func removeDeviceListener() {
        guard let device else { return }
        var address = CMIOProperties.address(CameraConfiguration.sourceDemandSelector)
        CMIOObjectRemovePropertyListenerBlock(device, &address, queue, demandChanged)
        self.device = nil
    }

    private func readDemand() {
        let value = device.flatMap { try? CMIOProperties.string($0, selector: CameraConfiguration.sourceDemandSelector) }
        let requested = value == "1"
        guard requested != active else { return }
        active = requested
        DispatchQueue.main.async { [onChange] in onChange(requested) }
    }
}
