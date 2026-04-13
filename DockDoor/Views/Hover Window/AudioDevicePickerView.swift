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
    private var listenerBlock: AudioObjectPropertyListenerBlock?

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
                                                 mElement: kAudioObjectPropertyElementMaster)

        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(systemID, &address, 0, nil, &dataSize)
        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        AudioObjectGetPropertyData(systemID, &address, 0, nil, &dataSize, &ids)

        var list: [AudioOutputDevice] = []

        for id in ids {
            var nameAddr = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName,
                                                      mScope: kAudioObjectPropertyScopeGlobal,
                                                      mElement: kAudioObjectPropertyElementMaster)
            var cfName: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            guard AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, &cfName) == noErr else { continue }

            var streamAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                                        mScope: kAudioDevicePropertyScopeOutput,
                                                        mElement: kAudioObjectPropertyElementMaster)
            var cfgSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streamAddr, 0, nil, &cfgSize) == noErr else { continue }
            let ptr = UnsafeMutableRawPointer.allocate(byteCount: Int(cfgSize), alignment: MemoryLayout<AudioBufferList>.alignment)
            defer { ptr.deallocate() }
            guard AudioObjectGetPropertyData(id, &streamAddr, 0, nil, &cfgSize, ptr) == noErr else { continue }
            let listPtr = ptr.bindMemory(to: AudioBufferList.self, capacity: 1)
            let buffers = UnsafeBufferPointer(start: &listPtr.pointee.mBuffers,
                                              count: Int(listPtr.pointee.mNumberBuffers))
            let channels = buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
            guard channels > 0 else { continue }

            list.append(AudioOutputDevice(id: id, name: cfName as String))
        }

        var defID = AudioObjectID(0)
        var defSize = UInt32(MemoryLayout<AudioObjectID>.size)
        var defAddr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMaster)
        AudioObjectGetPropertyData(systemID, &defAddr, 0, nil, &defSize, &defID)

        DispatchQueue.main.async { [weak self] in
            self?.devices = list
            self?.currentDevice = list.first(where: { $0.id == defID })
        }
    }

    func setDefault(device: AudioOutputDevice) {
        var id = device.id
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMaster)
        if AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &id) == noErr {
            DispatchQueue.main.async { [weak self] in self?.currentDevice = device }
        }
    }

    private func startListening() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refresh()
        }
        listenerBlock = block
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMaster)
        AudioObjectAddPropertyListenerBlock(systemID, &addr, DispatchQueue.main, block)
    }

    private func stopListening() {
        guard let block = listenerBlock else { return }
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMaster)
        AudioObjectRemovePropertyListenerBlock(systemID, &addr, DispatchQueue.main, block)
        listenerBlock = nil
    }
}

struct AudioDevicePickerView: View {
    @StateObject private var manager = AudioDeviceManager()

    var body: some View {
        Menu {
            ForEach(manager.devices) { device in
                Button {
                    manager.setDefault(device: device)
                } label: {
                    if device == manager.currentDevice {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
        }
        .fixedSize()
    }
}
