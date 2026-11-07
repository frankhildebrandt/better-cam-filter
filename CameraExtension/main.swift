import CoreMediaIO
import Foundation

let providerSource = try CameraProvider(cameraName: CameraConfiguration.name)
CMIOExtensionProvider.startService(provider: providerSource.provider)
CFRunLoopRun()
