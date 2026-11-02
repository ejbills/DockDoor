import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AddBlacklistAppSheet: View {
    @Binding var isPresented: Bool
    @Binding var appNameToAdd: String
    var onAdd: (String) -> Void

    @State private var selectedAppInfo: String = ""
    @State private var isLoadingAppInfo: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Add App to Blacklist")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text("Select an application:")
                    .font(.subheadline)

                Button(action: selectAppFile) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Browse for .app file...")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isLoadingAppInfo)

                if isLoadingAppInfo {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Reading app information...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !selectedAppInfo.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected app:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(selectedAppInfo)
                            .font(.subheadline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                    }
                }

                Text("This will add the app to the blacklist using its bundle identifier for reliable matching.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    resetState()
                    isPresented = false
                }
                .buttonStyle(.automatic)
                .keyboardShortcut(.escape)

                Spacer()
            }
        }
        .padding()
        .frame(width: 450, height: 200)
    }

    private func selectAppFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.prompt = "Select Application"
        panel.message = "Choose an application to add to the blacklist"

        if panel.runModal() == .OK, let url = panel.url {
            isLoadingAppInfo = true

            DispatchQueue.global(qos: .userInitiated).async {
                let bundle = Bundle(url: url)
                let appName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent

                let bundleIdentifier = bundle?.bundleIdentifier ?? ""

                DispatchQueue.main.async {
                    let appToAdd: String
                    if !bundleIdentifier.isEmpty {
                        appToAdd = bundleIdentifier
                        selectedAppInfo = "\(appName) (\(bundleIdentifier))"
                    } else {
                        appToAdd = appName
                        selectedAppInfo = appName
                    }

                    onAdd(appToAdd)
                    resetState()
                    isPresented = false
                    isLoadingAppInfo = false
                }
            }
        }
    }

    private func resetState() {
        appNameToAdd = ""
        selectedAppInfo = ""
        isLoadingAppInfo = false
    }
}
