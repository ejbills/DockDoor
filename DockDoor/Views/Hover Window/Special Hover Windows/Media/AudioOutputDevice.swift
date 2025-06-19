import CoreAudio
import SwiftUI

struct AudioOutputDevice: Identifiable, Equatable {
    let id: AudioObjectID
    let name: String
}

final class AudioDeviceManager: ObservableObject {
    @Published var devices: [AudioOutputDevice] = []
    @Published var currentDevice: AudioOutputDevice?

    private let systemID = AudioObjectID(kAudioObjectSystemObject)

    init() {
        refresh()
        startListening()
    }

    deinit {
        stopListening()
    }

    func refresh() {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)

        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(systemID, &address, 0, nil, &dataSize)
        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        AudioObjectGetPropertyData(systemID, &address, 0, nil, &dataSize, &ids)

        var list: [AudioOutputDevice] = []

        for id in ids {
            var nameAddr = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName,
                                                      mScope: kAudioObjectPropertyScopeGlobal,
                                                      mElement: kAudioObjectPropertyElementMain)

            var nameSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &nameAddr, 0, nil, &nameSize) == noErr else { continue }

            let namePtr = UnsafeMutableRawPointer.allocate(byteCount: Int(nameSize), alignment: MemoryLayout<CFString>.alignment)
            defer { namePtr.deallocate() }

            guard AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, namePtr) == noErr else { continue }
            let cfName = namePtr.load(as: CFString.self)

            var streamAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                                        mScope: kAudioDevicePropertyScopeOutput,
                                                        mElement: kAudioObjectPropertyElementMain)
            var cfgSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streamAddr, 0, nil, &cfgSize) == noErr else { continue }
            let ptr = UnsafeMutableRawPointer.allocate(byteCount: Int(cfgSize), alignment: MemoryLayout<AudioBufferList>.alignment)
            defer { ptr.deallocate() }
            guard AudioObjectGetPropertyData(id, &streamAddr, 0, nil, &cfgSize, ptr) == noErr else { continue }
            let listPtr = ptr.bindMemory(to: AudioBufferList.self, capacity: 1)

            let channels = withUnsafePointer(to: &listPtr.pointee.mBuffers) { buffersPtr in
                let buffers = UnsafeBufferPointer(start: buffersPtr, count: Int(listPtr.pointee.mNumberBuffers))
                return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
            }
            guard channels > 0 else { continue }

            list.append(AudioOutputDevice(id: id, name: cfName as String))
        }

        var defID = AudioObjectID(0)
        var defSize = UInt32(MemoryLayout<AudioObjectID>.size)
        var defAddr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(systemID, &defAddr, 0, nil, &defSize, &defID)

        DispatchQueue.main.async {
            self.devices = list
            self.currentDevice = list.first(where: { $0.id == defID })
        }
    }

    func setDefault(device: AudioOutputDevice) {
        var id = device.id
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        if AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &id) == noErr {
            DispatchQueue.main.async {
                self.currentDevice = device
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            }
        }
    }

    private func startListening() {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(systemID, &addr, DispatchQueue.main) { _, _ in
            self.refresh()
        }
    }

    private func stopListening() {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        AudioObjectRemovePropertyListenerBlock(systemID, &addr, DispatchQueue.main) { _, _ in
        }
    }
}

struct AudioDevicePickerView: View {
    @StateObject private var manager = AudioDeviceManager()

    var body: some View {
        Menu {
            if manager.devices.isEmpty {
                Text("No audio devices found")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(manager.devices) { device in
                    Button {
                        manager.setDefault(device: device)
                    } label: {
                        HStack {
                            Text(device.name)
                            Spacer()
                            if device == manager.currentDevice {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(manager.currentDevice?.name ?? "Audio Device")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}
