//
//  PermView.swift
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

struct PermView: View {
    @StateObject private var permissionsChecker = PermissionsChecker()

    var body: some View {
        if true { // As requested, the block to render the view
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Accessibility Permissions:")
                    Spacer()
                    Image(systemName: permissionsChecker.accessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(permissionsChecker.accessibilityPermission ? .green : .red)
                }
                HStack {
                    Text("Screen Recording Permissions:")
                    Spacer()
                    Image(systemName: permissionsChecker.screenRecordingPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(permissionsChecker.screenRecordingPermission ? .green : .red)
                }
                Button("Open Accessibility Settings", action: openAccessibilityPreferences)
                Button("Open Screen Recording Settings", action: openScreenRecordingPreferences)
                Button("Quit App to Apply Settings", action: quitApp)
                Spacer()
            }
            .padding()
        }
    }

    private func openAccessibilityPreferences() {
        SystemPreferencesHelper.openAccessibilityPreferences()
    }

    private func openScreenRecordingPreferences() {
        SystemPreferencesHelper.openScreenRecordingPreferences()
    }
}
