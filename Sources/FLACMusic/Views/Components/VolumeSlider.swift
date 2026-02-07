import SwiftUI

struct VolumeSlider: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors

    var body: some View {
        @Bindable var state = playerState
        HStack(spacing: 6) {
            Image(systemName: volumeIcon)
                .font(.caption)
                .foregroundStyle(colors.textTertiary)
                .frame(width: 14)

            Slider(value: $state.volume, in: 0...1)
                .tint(colors.accent)
                .frame(width: 80)

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(colors.textTertiary)
                .frame(width: 14)
        }
    }

    private var volumeIcon: String {
        if playerState.volume == 0 {
            return "speaker.slash.fill"
        } else if playerState.volume < 0.33 {
            return "speaker.fill"
        } else if playerState.volume < 0.66 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }
}
