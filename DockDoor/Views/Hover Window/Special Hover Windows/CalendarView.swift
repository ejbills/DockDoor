import AppKit
import Defaults
import EventKit
import os.log
import SwiftUI

struct CalendarView: View {
    // MARK: – Dependencies

    @StateObject private var calendarInfo = DailyCalendarInfo()

    let appName: String
    let bundleIdentifier: String
    let dockPosition: DockPosition
    let bestGuessMonitor: NSScreen
    let isEmbeddedMode: Bool
    let isPinnedMode: Bool

    // MARK: – Defaults

    @Default(.uniformCardRadius) private var uniformCardRadius
    @Default(.showAppName) private var showAppTitleData
    @Default(.showAppIconOnly) private var showAppIconOnly
    @Default(.appNameStyle) private var appNameStyle

    // MARK: – State

    @State private var appIcon: NSImage? = nil
    @State private var hoveringAppIcon = false
    @State private var hoveringWindowTitle = false
    @State private var showToast: Bool = false

    @Environment(\.openURL) private var openURL

    // MARK: – Layout Constants

    private enum Layout {
        static let containerSpacing: CGFloat = 8
        static let sectionSpacing: CGFloat = 12
        static let eventRowSpacing: CGFloat = 10
        static let skeletonOpacity: Double = 0.25
        static let embeddedEventRowSpacing: CGFloat = 6
        static let embeddedEventHeight: CGFloat = 40
    }

    // MARK: – Init

    init(appName: String,
         bundleIdentifier: String,
         dockPosition: DockPosition,
         bestGuessMonitor: NSScreen,
         isEmbeddedMode: Bool = false,
         isPinnedMode: Bool = false)
    {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.dockPosition = dockPosition
        self.bestGuessMonitor = bestGuessMonitor
        self.isEmbeddedMode = isEmbeddedMode
        self.isPinnedMode = isPinnedMode
    }

    // MARK: – Body

    var body: some View {
        Group {
            if isEmbeddedMode {
                embeddedContent()
            } else {
                fullContent()
            }
        }
        .onAppear {
            loadAppIcon()
        }
        .onChange(of: calendarInfo.events.count) { _ in
        }
        .onChange(of: calendarInfo.eventAuthStatus) { _ in
        }
    }

    @ViewBuilder
    private func embeddedContent() -> some View {
        let currentEventAuth = calendarInfo.eventAuthStatus
        let isLoadingCalendar = currentEventAuth == .notDetermined

        VStack(alignment: .leading, spacing: 8) {
            if isLoadingCalendar {
                embeddedCalendarSkeleton()
            } else if currentEventAuth == .denied || currentEventAuth == .restricted {
                embeddedPermissionNeededView()
            } else if currentEventAuth == .authorized {
                if !calendarInfo.events.isEmpty {
                    VStack(alignment: .leading, spacing: Layout.embeddedEventRowSpacing) {
                        Text("Today")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        LazyVStack(alignment: .leading, spacing: Layout.embeddedEventRowSpacing) {
                            ForEach(calendarInfo.events.prefix(3)) { event in
                                EmbeddedEventRowView(event: event)
                            }

                            if calendarInfo.events.count > 3 {
                                Text("+\(calendarInfo.events.count - 3) more")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 8)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("No events today")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: uniformCardRadius ? 12 : 0, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: uniformCardRadius ? 12 : 0, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func EmbeddedEventRowView(event: DailyCalendarInfo.Event) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(dateIntervalString(for: event))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let location = event.location {
                Text(location)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: Layout.embeddedEventHeight, alignment: .leading)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func embeddedCalendarSkeleton() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(Layout.skeletonOpacity))
                .frame(width: 80, height: 12)

            VStack(alignment: .leading, spacing: Layout.embeddedEventRowSpacing) {
                ForEach(0 ..< 2) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(Layout.skeletonOpacity * 0.5))
                        .frame(height: Layout.embeddedEventHeight)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: uniformCardRadius ? 12 : 0, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: uniformCardRadius ? 12 : 0, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .glintPlaceholder()
    }

    @ViewBuilder
    private func embeddedPermissionNeededView() -> some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title3)
                .foregroundStyle(.orange)

            Text("Calendar Access Needed")
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)

            Button("Grant Access") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    openURL(url)
                }
            }
            .buttonStyle(AccentButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func fullContent() -> some View {
        if isPinnedMode {
            pinnedContent()
        } else {
            regularContent()
        }
    }

    @ViewBuilder
    private func regularContent() -> some View {
        BaseHoverContainer(
            bestGuessMonitor: bestGuessMonitor,
            mockPreviewActive: false,
            content: {
                VStack(spacing: 0) {
                    calendarContent()
                        .globalPadding(20)
                }
                .padding(.top, (appNameStyle == .default && showAppTitleData) ? 25 : 0)
                .overlay(alignment: .topLeading) {
                    hoverTitleBaseView(labelSize: measureString(appName, fontSize: 14))
                        .onHover { isHovered in
                            withAnimation(.snappy) { hoveringWindowTitle = isHovered }
                        }
                }
                .padding(.top, (appNameStyle == .popover && showAppTitleData) ? 30 : 0)
                .overlay {
                    WindowDismissalContainer(appName: appName,
                                             bestGuessMonitor: bestGuessMonitor,
                                             dockPosition: dockPosition,
                                             minimizeAllWindowsCallback: {})
                        .allowsHitTesting(false)
                }
            },
            highlightColor: nil
        )
        .pinnable(appName: appName, bundleIdentifier: bundleIdentifier, type: .calendar)
    }

    @ViewBuilder
    private func pinnedContent() -> some View {
        VStack(spacing: 0) {
            calendarContent()
                .globalPadding(20)
        }
        .padding(.top, (appNameStyle == .default && showAppTitleData) ? 25 : 0)
        .overlay(alignment: .topLeading) {
            hoverTitleBaseView(labelSize: measureString(appName, fontSize: 14))
                .onHover { isHovered in
                    withAnimation(.snappy) { hoveringWindowTitle = isHovered }
                }
        }
        .padding(.top, (appNameStyle == .popover && showAppTitleData) ? 30 : 0)
        .dockStyle(cornerRadius: 16)
    }

    // MARK: – Main Content

    @ViewBuilder
    private func calendarContent() -> some View {
        let currentEventAuth = calendarInfo.eventAuthStatus
        let isLoadingCalendar = currentEventAuth == .notDetermined

        ScrollView(.vertical, showsIndicators: false) {
            if isLoadingCalendar {
                VStack {
                    calendarSkeleton()
                }
                .frame(maxWidth: .infinity)
            } else if currentEventAuth == .denied || currentEventAuth == .restricted {
                VStack {
                    permissionNeededView()
                }
                .frame(maxWidth: .infinity)
            } else if currentEventAuth == .authorized {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    if !calendarInfo.events.isEmpty {
                        Text("Today")
                            .font(.title3)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: Layout.eventRowSpacing) {
                            ForEach(calendarInfo.events) { event in
                                EventRowView(event: event)
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.largeTitle)
                                .fontWeight(.light)
                                .imageScale(.medium)
                                .foregroundStyle(.secondary)
                            Text("No events scheduled for today!")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Enjoy your free day or add some events to your calendar.")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(minHeight: 175, alignment: calendarInfo.events.isEmpty ? .center : .topLeading)
            }
        }
    }

    // MARK: – Skeleton Placeholder

    @ViewBuilder
    private func calendarSkeleton() -> some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing + 8) {
            RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(Layout.skeletonOpacity)).frame(width: 120, height: 24)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: Layout.eventRowSpacing) {
                ForEach(0 ..< 3) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.primary.opacity(Layout.skeletonOpacity * 0.5))
                        .frame(height: 70)
                        .overlay(alignment: .leading) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(Layout.skeletonOpacity))
                                    .frame(width: 6, height: 50)
                                    .padding(.leading, 12)

                                VStack(alignment: .leading, spacing: 6) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(Layout.skeletonOpacity)).frame(height: 16)
                                    RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(Layout.skeletonOpacity)).frame(height: 12)
                                    RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(Layout.skeletonOpacity)).frame(width: 75, height: 10)
                                }
                            }
                            .padding(.trailing, 4)
                        }
                }
            }
        }
        .glintPlaceholder()
    }

    @ViewBuilder
    private func EventRowView(event: DailyCalendarInfo.Event) -> some View {
        let cornerRadius = 16.0

        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(dateIntervalString(for: event))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let location = event.location {
                HStack(spacing: 3) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(Color.gray.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
    }

    // MARK: – Helpers

    private func dateIntervalString(for event: DailyCalendarInfo.Event) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: event.startDate, to: event.endDate)
    }

    private func loadAppIcon() {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first,
           let icon = app.icon
        {
            DispatchQueue.main.async {
                if appIcon != icon { appIcon = icon }
            }
        } else if appIcon != nil {
            DispatchQueue.main.async { appIcon = nil }
        }
    }

    @ViewBuilder
    private func permissionNeededView() -> some View {
        VStack(spacing: 8) {
            Label {
                Text(" ")
            } icon: {
                Image(systemName: "calendar.badge.exclamationmark")
            }
            .labelStyle(.iconOnly)
            .font(.largeTitle)
            .fontWeight(.light)
            .imageScale(.large)
            .foregroundStyle(.orange)

            Text("Calendar Access Needed")
                .font(.title2)
                .fontWeight(.medium)
            Text("DockDoor needs permission to access your calendar.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open System Privacy Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    openURL(url)
                }
            }
            .buttonStyle(AccentButtonStyle())
        }
    }

    // MARK: – Hover Title Views

    @ViewBuilder
    private func hoverTitleBaseView(labelSize: CGSize) -> some View {
        if showAppTitleData {
            Group {
                switch appNameStyle {
                case .default:
                    HStack {
                        if let appIcon {
                            Image(nsImage: appIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        } else {
                            ProgressView().frame(width: 24, height: 24)
                        }
                        hoverTitleLabelView(labelSize: labelSize)
                    }
                    .padding(.top, 10)
                    .padding(.horizontal)
                    .animation(.smooth(duration: 0.15), value: hoveringAppIcon)

                case .shadowed:
                    HStack(spacing: 2) {
                        if let appIcon {
                            Image(nsImage: appIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        } else {
                            ProgressView().frame(width: 24, height: 24)
                        }
                        hoverTitleLabelView(labelSize: labelSize)
                    }
                    .padding(EdgeInsets(top: -11.5, leading: 15, bottom: -1.5, trailing: 1.5))
                    .animation(.smooth(duration: 0.15), value: hoveringAppIcon)

                case .popover:
                    HStack {
                        Spacer()
                        HStack(spacing: 2) {
                            if let appIcon {
                                Image(nsImage: appIcon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            } else {
                                ProgressView().frame(width: 24, height: 24)
                            }
                            hoverTitleLabelView(labelSize: labelSize)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .dockStyle(cornerRadius: 10)
                        Spacer()
                    }
                    .offset(y: -30)
                    .animation(.smooth(duration: 0.15), value: hoveringAppIcon)
                }
            }
            .onHover { hover in
                hoveringAppIcon = hover
            }
        }
    }

    @ViewBuilder
    private func hoverTitleLabelView(labelSize: CGSize) -> some View {
        if !showAppIconOnly {
            let trimmedAppName = appName.trimmingCharacters(in: .whitespaces)
            let baseText = Text(trimmedAppName).font(.subheadline).fontWeight(.medium)

            switch appNameStyle {
            case .shadowed:
                baseText.foregroundStyle(Color.primary).shadow(stacked: 2, radius: 6)
            case .default, .popover:
                baseText.foregroundStyle(Color.primary)
            }
        }
    }

    private func measureString(_ string: String, fontSize: CGFloat) -> CGSize {
        let font = NSFont.systemFont(ofSize: fontSize)
        let attributes = [NSAttributedString.Key.font: font]
        return (string as NSString).size(withAttributes: attributes)
    }
}
