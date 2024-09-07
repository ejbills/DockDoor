//
//  WhyWeNeedPermisionsView.swift
//  DockDoor
//
//  Created by Igor Marcossi on 06/09/24.
//

import SwiftUI

struct WhyWeNeedPermisionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Why we need permissions")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 10) {
                Text("Accessibility:")
                    .font(.headline)
                Text("• To detect when you hover over the dock")
                Text("• Enables real-time interaction with dock items")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Screen Capturing:")
                    .font(.headline)
                Text("• To capture previews of images and windows")
                Text("• Allows for enhanced visual information in the dock")
            }
        }
        .padding()
    }
}

#Preview {
    WhyWeNeedPermisionsView()
}
