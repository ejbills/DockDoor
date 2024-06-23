//
//  UpdateView.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/23/24.
//

import SwiftUI
import Sparkle

// This view model class publishes when new updates can be checked by the user
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

// This is the view for the Check for Updates menu item
// Note this intermediate view is necessary for the disabled state on the menu item to work properly before Monterey.
// See https://stackoverflow.com/questions/68553092/menu-not-updating-swiftui-bug for more info
struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater
    
    init(updater: SPUUpdater) {
        self.updater = updater
        
        // Create our view model for our CheckForUpdatesView
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: checkForUpdatesViewModel.canCheckForUpdates ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(checkForUpdatesViewModel.canCheckForUpdates ? .green : .red)
                    .scaleEffect(checkForUpdatesViewModel.canCheckForUpdates ? 1.2 : 1.0)
                    .padding(10)
                
                Text("Can check for updates")
                    .font(.headline)
            }
            
            Button(action: updater.checkForUpdates) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Check for Updates…")
                }
            }
            .buttonStyle(.bordered)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
            
            Spacer()
        }
        .padding(20)
    }
}
