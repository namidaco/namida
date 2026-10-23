// by claude
import ActivityKit
import SwiftUI
import WidgetKit

/// the playing line of the lyrics on the lock screen & the dynamic island, started and updated by the app.
struct LyricsLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: NamidaLyricsActivityAttributes.self) { context in
      LyricsLockScreenView(state: context.state)
        .activityBackgroundTint(Color.black.opacity(0.65))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "music.note")
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.state.title)
            .font(.headline)
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.state.line ?? context.state.artist ?? "")
            .font(.body)
            .lineLimit(2)
            .multilineTextAlignment(.center)
        }
      } compactLeading: {
        Image(systemName: "music.note")
      } compactTrailing: {
        Text(context.state.line ?? "")
          .font(.caption2)
          .lineLimit(1)
          .frame(maxWidth: 72)
      } minimal: {
        Image(systemName: "music.note")
      }
    }
  }
}

struct LyricsLockScreenView: View {
  let state: NamidaLyricsActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Image(systemName: "music.note")
        Text(state.title)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        if let artist = state.artist, !artist.isEmpty {
          Text(artist)
            .font(.subheadline)
            .opacity(0.7)
            .lineLimit(1)
        }
      }
      if let line = state.line, !line.isEmpty {
        Text(line)
          .font(.title3.weight(.semibold))
          .lineLimit(2)
      }
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
  }
}
