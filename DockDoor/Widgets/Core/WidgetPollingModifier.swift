import SwiftUI

/// Simple callback-based polling modifier for declarative widgets
struct CallbackPollingModifier: ViewModifier {
    let provider: WidgetStatusProvider
    let onUpdate: ([String: String]) -> Void

    @State private var pollTimer: Timer?

    func body(content: Content) -> some View {
        content
            .onAppear {
                startPolling()
            }
            .onDisappear {
                stopPolling()
            }
    }

    private func startPolling() {
        guard pollTimer == nil else { return }

        let interval = TimeInterval(provider.pollIntervalMs) / 1000.0
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                await pollStatus()
            }
        }

        // Initial poll
        Task { await pollStatus() }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    @MainActor
    private func pollStatus() async {
        let result = await Task.detached {
            AppleScriptExecutor.run(provider.statusScript)
        }.value

        guard let output = result.output else { return }

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
    /// Adds callback-based polling for declarative widgets
    func widgetPolling(provider: WidgetStatusProvider?, onUpdate: @escaping ([String: String]) -> Void) -> some View {
        if let provider {
            AnyView(modifier(CallbackPollingModifier(provider: provider, onUpdate: onUpdate)))
        } else {
            AnyView(self)
        }
    }
}
