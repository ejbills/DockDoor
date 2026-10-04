import SwiftUI

// Oversized on purpose: the OS getters write the runtime type's full size into this buffer, so it must never shrink below it.
private struct PrivateGlassStorage {
    private typealias Block = (UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64)
    private var storage: (Block, Block)
}

@available(macOS 26.0, *)
enum LiquidGlass {
    private typealias GlassGetter = @convention(thin) () -> PrivateGlassStorage
    private typealias GlassInitializer = @convention(thin) (PrivateGlassStorage) -> Glass

    private struct Variant {
        let flavor: DockLiquidGlassFlavor
        let symbol: String

        var getter: GlassGetter? { resolveGetter(symbol) }
    }

    private static let privateGlassTypeName = "7SwiftUI6_GlassV"
    private static let explicitGlassInitSymbol = "$s7SwiftUI5GlassV8explicitAcA01_C0V_tcfC"
    private static let focusBorderSymbol = "$s7SwiftUI6_GlassV11focusBorderACvgZ"
    private static let forceActiveAppearanceSymbol = "$s7SwiftUI6_GlassV14VariantOptionsV21forceActiveAppearanceAEvgZ"

    private static let opacityOrdered: [Variant] = [
        Variant(flavor: .monogram, symbol: "$s7SwiftUI6_GlassV8monogramACvgZ"),
        Variant(flavor: .loupe, symbol: "$s7SwiftUI6_GlassV5loupeACvgZ"),
        Variant(flavor: .avPlayer, symbol: "$s7SwiftUI6_GlassV8avplayerACvgZ"),
        Variant(flavor: .clearGlass, symbol: "$s7SwiftUI6_GlassV5clearACvgZ"),
        Variant(flavor: .dock, symbol: "$s7SwiftUI6_GlassV4dockACvgZ"),
        Variant(flavor: .controlCenter, symbol: "$s7SwiftUI6_GlassV13controlCenterACvgZ"),
        Variant(flavor: .widgets, symbol: "$s7SwiftUI6_GlassV7widgetsACvgZ"),
        Variant(flavor: .cartouchePopover, symbol: "$s7SwiftUI6_GlassV16cartouchePopoverACvgZ"),
        Variant(flavor: .sidebar, symbol: "$s7SwiftUI6_GlassV7sidebarACvgZ"),
        Variant(flavor: .regular, symbol: "$s7SwiftUI6_GlassV7regularACvgZ"),
        Variant(flavor: .notificationCenter, symbol: "$s7SwiftUI6_GlassV18notificationCenterACvgZ"),
        Variant(flavor: .menu, symbol: "$s7SwiftUI6_GlassV4menuACvgZ"),
        Variant(flavor: .camera, symbol: "$s7SwiftUI6_GlassV6cameraACvgZ"),
        Variant(flavor: .appIcons, symbol: "$s7SwiftUI6_GlassV8appIconsACvgZ"),
        Variant(flavor: .siriSnippet, symbol: "$s7SwiftUI6_GlassV11siriSnippetACvgZ"),
        Variant(flavor: .siri, symbol: "$s7SwiftUI6_GlassV4siriACvgZ"),
        Variant(flavor: .keyboard, symbol: "$s7SwiftUI6_GlassV8keyboardACvgZ"),
    ]

    private static let processHandle = dlopen(nil, RTLD_NOW)

    private static func resolveGetter(_ symbol: String) -> GlassGetter? {
        guard let pointer = dlsym(processHandle, symbol) else { return nil }
        // Keep the Swift calling convention used by these private getters.
        return unsafeBitCast(pointer, to: GlassGetter.self)
    }

    // Isolate indirect Swift ABI calls from optimizer result-layout rewriting.
    @inline(never)
    private static func readGlass(_ getter: GlassGetter) -> PrivateGlassStorage {
        getter()
    }

    @inline(never)
    private static func constructGlass(_ initializer: GlassInitializer, _ storage: PrivateGlassStorage) -> Glass {
        initializer(storage)
    }

    private static let initializeGlass: GlassInitializer? = {
        guard let pointer = dlsym(processHandle, explicitGlassInitSymbol) else { return nil }
        return unsafeBitCast(pointer, to: GlassInitializer.self)
    }()

    private static func runtimeTypeFits<T>(_ typeName: String, in _: T.Type) -> Bool {
        guard let runtimeType = _typeByName(typeName) else { return false }
        func fits<U>(_: U.Type) -> Bool {
            MemoryLayout<U>.size > 32
                && MemoryLayout<U>.size <= MemoryLayout<T>.size
                && MemoryLayout<U>.alignment <= MemoryLayout<T>.alignment
        }
        return _openExistential(runtimeType, do: fits)
    }

    static let usesModernPipeline: Bool = {
        guard #available(macOS 27.0, *) else { return false }
        return supportsModernGlass && !availableFlavors.isEmpty
    }()

    static let availableFlavors: [DockLiquidGlassFlavor] = {
        guard supportsModernGlass else { return [] }
        return opacityOrdered.filter { $0.getter != nil }.map(\.flavor)
    }()

    private static let supportsModernGlass: Bool = runtimeTypeFits(privateGlassTypeName, in: PrivateGlassStorage.self)
        && initializeGlass != nil

    static func sliderIndex(for flavor: DockLiquidGlassFlavor) -> Int {
        if let index = availableFlavors.firstIndex(of: flavor) { return index }
        guard let targetPosition = opacityOrdered.firstIndex(where: { $0.flavor == flavor }) else {
            return availableFlavors.count / 2
        }
        var bestIndex = availableFlavors.count / 2
        var bestDistance = Int.max
        for (index, candidate) in availableFlavors.enumerated() {
            guard let position = opacityOrdered.firstIndex(where: { $0.flavor == candidate }) else { continue }
            let distance = abs(position - targetPosition)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }

    private struct GlassKey: Hashable {
        let flavor: DockLiquidGlassFlavor
        let activeAppearance: Bool
    }

    @MainActor private static var glassCache: [GlassKey: Glass] = [:]
    @MainActor private static var borderGlassCache: [Bool: Glass] = [:]

    private struct VariantOptionsLayout {
        let addedOptionsOffset: Int
        let removedOptionsOffset: Int

        func adding(_ bits: UInt64, to storage: PrivateGlassStorage) -> PrivateGlassStorage {
            var patched = storage
            withUnsafeMutableBytes(of: &patched) { raw in
                let added = raw.load(fromByteOffset: addedOptionsOffset, as: UInt64.self)
                let removed = raw.load(fromByteOffset: removedOptionsOffset, as: UInt64.self)
                raw.storeBytes(of: added | bits, toByteOffset: addedOptionsOffset, as: UInt64.self)
                raw.storeBytes(of: removed & ~bits, toByteOffset: removedOptionsOffset, as: UInt64.self)
            }
            return patched
        }
    }

    private static let forceActiveAppearanceBit = variantOptionBit(forceActiveAppearanceSymbol)

    private static func variantOptionBit(_ symbol: String) -> UInt64? {
        guard let getter = resolveGetter(symbol) else { return nil }
        let bit = withUnsafeBytes(of: readGlass(getter)) { $0.load(as: UInt64.self) }
        return bit.nonzeroBitCount == 1 ? bit : nil
    }

    private static let variantOptionsLayout: VariantOptionsLayout? = {
        guard supportsModernGlass, let bit = forceActiveAppearanceBit,
              let glassType = _typeByName(privateGlassTypeName),
              let getter = opacityOrdered.first(where: { $0.getter != nil })?.getter
        else { return nil }
        let probe = readGlass(getter)
        guard let offsets = variantOptionOffsets(of: probe, glassType: glassType) else { return nil }
        let layout = VariantOptionsLayout(addedOptionsOffset: offsets.added, removedOptionsOffset: offsets.removed)
        let variant = Mirror(reflecting: reflectedGlass(layout.adding(bit, to: probe), glassType: glassType)).descendant("variant")
        guard let variant,
              let added = Mirror(reflecting: variant).descendant("addedOptions", "rawValue") as? Int,
              let removed = Mirror(reflecting: variant).descendant("removedOptions", "rawValue") as? Int,
              UInt64(bitPattern: Int64(added)) & bit != 0,
              UInt64(bitPattern: Int64(removed)) & bit == 0
        else { return nil }
        return layout
    }()

    private static func reflectedGlass(_ storage: PrivateGlassStorage, glassType: Any.Type) -> Any {
        func load<T>(_: T.Type) -> Any {
            withUnsafeBytes(of: storage) { $0.load(as: T.self) }
        }
        return _openExistential(glassType, do: load)
    }

    private static func variantOptionOffsets(of storage: PrivateGlassStorage, glassType: Any.Type) -> (added: Int, removed: Int)? {
        guard let variantField = Mirror(reflecting: reflectedGlass(storage, glassType: glassType)).children.first,
              variantField.label == "variant"
        else { return nil }
        func layout<T>(_: T.Type) -> (size: Int, alignment: Int) {
            (MemoryLayout<T>.size, MemoryLayout<T>.alignment)
        }
        var offset = 0
        var optionOffsets: [String: Int] = [:]
        for field in Mirror(reflecting: variantField.value).children {
            let fieldLayout = _openExistential(type(of: field.value), do: layout)
            offset = (offset + fieldLayout.alignment - 1) / fieldLayout.alignment * fieldLayout.alignment
            if let label = field.label, fieldLayout.size == MemoryLayout<UInt64>.size {
                optionOffsets[label] = offset
            }
            offset += fieldLayout.size
        }
        guard offset == _openExistential(type(of: variantField.value), do: layout).size,
              let added = optionOffsets["addedOptions"],
              let removed = optionOffsets["removedOptions"],
              max(added, removed) + MemoryLayout<UInt64>.size <= MemoryLayout<PrivateGlassStorage>.size
        else { return nil }
        return (added, removed)
    }

    private static func makeGlass(_ storage: PrivateGlassStorage, activeAppearance: Bool) -> Glass? {
        guard let initializeGlass else { return nil }
        var bits: UInt64 = 0
        if activeAppearance, let forceActiveAppearanceBit { bits |= forceActiveAppearanceBit }
        guard bits != 0, let variantOptionsLayout else {
            return constructGlass(initializeGlass, storage)
        }
        return constructGlass(initializeGlass, variantOptionsLayout.adding(bits, to: storage))
    }

    @MainActor
    static func borderGlass(activeAppearance: Bool = false) -> Glass? {
        if let cached = borderGlassCache[activeAppearance] { return cached }
        guard usesModernPipeline,
              let getter = resolveGetter(focusBorderSymbol),
              let glass = makeGlass(readGlass(getter), activeAppearance: activeAppearance)
        else { return nil }
        borderGlassCache[activeAppearance] = glass
        return glass
    }

    @MainActor
    static func glass(for flavor: DockLiquidGlassFlavor, activeAppearance: Bool = false) -> Glass? {
        guard usesModernPipeline else { return nil }
        let index = sliderIndex(for: flavor)
        guard availableFlavors.indices.contains(index) else { return nil }
        let key = GlassKey(flavor: availableFlavors[index], activeAppearance: activeAppearance)
        if let cached = glassCache[key] { return cached }
        guard let getter = opacityOrdered.first(where: { $0.flavor == key.flavor })?.getter,
              let glass = makeGlass(readGlass(getter), activeAppearance: activeAppearance)
        else { return nil }
        glassCache[key] = glass
        return glass
    }
}
