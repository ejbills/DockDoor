import Defaults
import SwiftUI

struct DockDoorProBanner: View {
    @Default(.hideDockDoorProBanner) private var hideDockDoorProBanner

    var body: some View {
        if !hideDockDoorProBanner {
            HStack(alignment: .top, spacing: 14) {
                DockDoorProIcon()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(String(localized: "DockDoor Pro", comment: "DockDoor Pro banner title"))
                            .font(.headline)
                        Text(String(localized: "$20 one-time", comment: "DockDoor Pro price tag"))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.mint.opacity(0.18), in: Capsule())
                    }

                    Text(String(localized: "DockDoor Free has no paywall and never will. Pro is a separate app that replaces the macOS Dock entirely for far deeper system control, and buying it is the best way to support the free project.", comment: "DockDoor Pro banner description"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Button {
                            DockDoorPro.open()
                        } label: {
                            Label(String(localized: "Get DockDoor Pro", comment: "DockDoor Pro banner link"), systemImage: "arrow.up.right")
                        }
                        .buttonStyle(AccentButtonStyle(color: .mint, small: true))

                        Text(String(localized: "3 Macs · 14-day money-back guarantee", comment: "DockDoor Pro banner fine print"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 12)

                Button { hideDockDoorProBanner = true } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Never show DockDoor Pro banner again", comment: "DockDoor Pro banner dismiss accessibility label"))
                .help(String(localized: "Never show again", comment: "DockDoor Pro banner dismiss help text"))
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct DockDoorProIcon: View {
    var size: CGFloat = 48

    var body: some View {
        AsyncImage(url: DockDoorPro.iconURL) { phase in
            switch phase {
            case let .success(image):
                image.resizable().scaledToFit()
            default:
                Image(systemName: "sparkles")
                    .font(.system(size: size / 2, weight: .medium))
                    .foregroundStyle(.mint)
            }
        }
        .frame(width: size, height: size)
        .background(Color.mint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: size / 4.8, style: .continuous))
    }
}
