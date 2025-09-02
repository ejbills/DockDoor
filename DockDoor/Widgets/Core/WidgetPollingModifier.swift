import SwiftUI

/// Callback-based polling modifier implemented with a cancellable async Task loop.
struct CallbackPollingModifier: ViewModifier {
    let provider: WidgetStatusProvider
    let onUpdate: ([String: String]) -> Void

    @State private var pollTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear { startPolling() }
            .onDisappear { stopPolling() }
    }

    private func startPolling() {
        guard pollTask == nil else { return }
        let intervalNs = UInt64(max(50, provider.pollIntervalMs)) * 1_000_000 // ms -> ns
        pollTask = Task { @MainActor in
            // Initial poll immediately
            await pollOnce()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNs)
                await pollOnce()
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    @MainActor
    private func pollOnce() async {
        let output = await Task.detached { AppleScriptExecutor.run(provider.statusScript) }.value
        guard let output else { return }

        let components = output.components(separatedBy: provider.delimiter)
        var context: [String: String] = [:]
        for (fieldName, index) in provider.fields {
            if index < components.count {
                context[fieldName] = components[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        onUpdate(context)
    }
}

extension View {
    /// Adds callback-based polling for declarative widgets.
    @ViewBuilder
    func widgetPolling(provider: WidgetStatusProvider?, onUpdate: @escaping ([String: String]) -> Void) -> some View {
        if let provider {
            modifier(CallbackPollingModifier(provider: provider, onUpdate: onUpdate))
        } else {
            self
        }
    }
}
