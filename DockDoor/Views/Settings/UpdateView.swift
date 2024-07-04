//
//  UpdateView.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/23/24.
//

import SwiftUI
import Sparkle

final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheckDate: Date?
    @Published var currentVersion: String
    @Published var isAutomaticChecksEnabled: Bool
    @Published var updateStatus: UpdateStatus = .noUpdates
    
    private let updater: SPUUpdater
    
    enum UpdateStatus {
        case noUpdates
        case checking
        case available(version: String)
        case error(String)
    }
    
    init(updater: SPUUpdater) {
        self.updater = updater
        self.currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        self.isAutomaticChecksEnabled = updater.automaticallyChecksForUpdates
        
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        
        updater.publisher(for: \.lastUpdateCheckDate)
            .assign(to: &$lastUpdateCheckDate)
    }
    
    func checkForUpdates() {
        updateStatus = .checking
        updater.checkForUpdates()
    }
    
    func toggleAutomaticChecks() {
        isAutomaticChecksEnabled.toggle()
        updater.automaticallyChecksForUpdates = isAutomaticChecksEnabled
    }
}

struct UpdateView: View {
    @StateObject private var viewModel: UpdaterViewModel
    
    init(updater: SPUUpdater) {
        _viewModel = StateObject(wrappedValue: UpdaterViewModel(updater: updater))
    }
    
    var body: some View {
        HStack {
            updateStatusView
            Spacer()

            Divider()
            
            Spacer()
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    Text("Current Version: \(viewModel.currentVersion)")
                    if let lastCheck = viewModel.lastUpdateCheckDate {
                        Text("Last checked: \(lastCheck, formatter: dateFormatter)")
                    }
                }
                
                Divider()
                Button(action: viewModel.checkForUpdates) {
                    Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!viewModel.canCheckForUpdates)
                
                Toggle("Automatically check for updates", isOn: $viewModel.isAutomaticChecksEnabled)
                    .onChange(of: viewModel.isAutomaticChecksEnabled) { _, _ in
                        viewModel.toggleAutomaticChecks()
                    }
            }
        }
        .padding()
        .frame(width: 600)
    }
    
    private var updateStatusView: some View {
        Group {
            switch viewModel.updateStatus {
            case .noUpdates:
                Label("Up to date", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .checking:
                ProgressView()
                    .scaleEffect(0.7)
            case .available(let version):
                VStack {
                    Label("Update available", systemImage: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                    Text("Version \(version)")
                        .font(.caption)
                }
            case .error(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
