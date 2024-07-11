//
//  PermissionsSettingsView.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/14/24.
//

import SwiftUI
import Combine
import AppKit

class PermissionsChecker: ObservableObject {
    @Published var accessibilityPermission: Bool = false
    @Published var screenRecordingPermission: Bool = false
    private var timer: AnyCancellable?

    init() {
        checkPermissions()
        startTimer()
    }

    deinit {
        timer?.cancel()
    }

    func checkPermissions() {
        accessibilityPermission = hasPermissions(for: .accessibility)
        screenRecordingPermission = hasPermissions(for: .screenRecording)
    }

    private func hasPermissions(for type: PermissionType) -> Bool {
        switch type {
        case .accessibility:
            return AXIsProcessTrusted()
        case .screenRecording:
            return CGPreflightScreenCaptureAccess()
        }
    }

    private func startTimer() {
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkPermissions()
            }
    }

    enum PermissionType {
        case accessibility
        case screenRecording
    }
}

struct PermissionsSettingsView: View {
    @StateObject private var permissionsChecker = PermissionsChecker()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: permissionsChecker.accessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(permissionsChecker.accessibilityPermission ? .green : .red)
                    .scaleEffect(permissionsChecker.accessibilityPermission ? 1.2 : 1.0)
                    .padding(10)
                
                Text("Accessibility Permissions")
                    .font(.headline)
            }
            
            HStack {
                Image(systemName: permissionsChecker.screenRecordingPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(permissionsChecker.screenRecordingPermission ? .green : .red)
                    .scaleEffect(permissionsChecker.screenRecordingPermission ? 1.2 : 1.0)
                    .padding(10)

                Text("Screen Recording Permissions")
                    .font(.headline)
            }
            
            Button(action: openAccessibilityPreferences) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                    Text("Open Accessibility Settings")
                }
            }
            .buttonStyle(.bordered)
            
            Button(action: openScreenRecordingPreferences) {
                HStack {
                    Image(systemName: "video.fill")
                    Text("Open Screen Recording Settings")
                }
            }
            .buttonStyle(.bordered)
            
            Text("Please Quit the App to Apply Changes! :)")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button("Quit App", action: quitApp)
                .buttonStyle(.bordered)

            Spacer()
        }
        .padding([.top, .leading, .trailing], 20)
        .frame(minWidth: 650)
    }
    
    private func openAccessibilityPreferences() {
        SystemPreferencesHelper.openAccessibilityPreferences()
    }
    
    private func openScreenRecordingPreferences() {
        SystemPreferencesHelper.openScreenRecordingPreferences()
    }
}
