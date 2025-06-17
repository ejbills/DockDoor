
import Defaults
import SwiftUI

struct MediaArtworkView: View {
    let artwork: NSImage?
    let size: CGSize
    let cornerRadius: CGFloat
    let artworkRotation: Double

    @Default(.showAnimations) var showAnimations

    var body: some View {
        ZStack {
            if let artwork {
                if artwork.isTemplate {
                    let iconScaleFactor: CGFloat = 0.45
                    let iconSize = min(size.width, size.height) * iconScaleFactor
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: size.width, height: size.height)
                        .overlay(
                            Image(nsImage: artwork)
                                .resizable()
                                .scaledToFit()
                                .frame(width: iconSize, height: iconSize)
                                .foregroundColor(Color.secondary.opacity(0.7))
                        )
                } else {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                }
            } else {
                let iconScaleFactor: CGFloat = 0.45
                let iconSize = min(size.width, size.height) * iconScaleFactor
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        Image(systemName: "music.note")
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .foregroundColor(Color.secondary.opacity(0.7))
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .rotation3DEffect(.degrees(artworkRotation), axis: (x: 0, y: 1, z: 0))
        .animation(showAnimations ? .smooth(duration: 0.35) : nil, value: artwork?.tiffRepresentation)
    }
}
