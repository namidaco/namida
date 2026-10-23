// by claude
import AppIntents
import SwiftUI
import WidgetKit

/// the playing item & its controls, written by the app through `NamidaWidgetsPlugin`.
struct NowPlayingWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: NamidaWidgetsShared.nowPlayingKind, provider: NowPlayingProvider()) { entry in
      NowPlayingWidgetView(entry: entry)
    }
    .configurationDisplayName("Now Playing")
    .description("The playing item with its controls.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct NowPlayingProvider: TimelineProvider {
  func placeholder(in context: Context) -> NowPlayingEntry {
    return .placeholder
  }

  func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
    completion(context.isPreview ? .placeholder : .current())
  }

  /// the app reloads the timeline itself whenever something changes.
  func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
    completion(Timeline(entries: [.current()], policy: .never))
  }
}

struct NowPlayingEntry: TimelineEntry {
  let date: Date
  let title: String
  let message: String?
  let isPlaying: Bool
  let isFavourite: Bool
  let artwork: UIImage?

  static let placeholder = NowPlayingEntry(date: Date(), title: "Namida", message: nil, isPlaying: false, isFavourite: false, artwork: nil)

  static func current() -> NowPlayingEntry {
    typealias Key = NamidaWidgetsShared.Key
    let defaults = NamidaWidgetsShared.defaults
    let artworkPath = NamidaWidgetsShared.artworkURL?.path
    let artwork = artworkPath.flatMap { UIImage(contentsOfFile: $0) }
    return NowPlayingEntry(
      date: Date(),
      title: defaults?.string(forKey: Key.title) ?? "Namida",
      message: defaults?.string(forKey: Key.message),
      isPlaying: defaults?.bool(forKey: Key.playing) ?? false,
      isFavourite: defaults?.bool(forKey: Key.favourite) ?? false,
      artwork: artwork
    )
  }
}

struct NowPlayingWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: NowPlayingEntry

  var body: some View {
    content
      .foregroundStyle(.white)
      .containerBackground(for: .widget) {
        NowPlayingBackground(artwork: entry.artwork)
      }
  }

  @ViewBuilder
  private var content: some View {
    switch family {
    case .systemMedium:
      HStack(spacing: 12) {
        NowPlayingArtwork(artwork: entry.artwork)
        VStack(alignment: .leading, spacing: 6) {
          NowPlayingTitles(entry: entry)
          Spacer(minLength: 0)
          NowPlayingControls(entry: entry, showsFavourite: true)
        }
      }
    default:
      VStack(alignment: .leading, spacing: 6) {
        NowPlayingTitles(entry: entry)
        Spacer(minLength: 0)
        NowPlayingControls(entry: entry, showsFavourite: false)
      }
    }
  }
}

struct NowPlayingBackground: View {
  let artwork: UIImage?

  var body: some View {
    ZStack {
      Color(red: 0.09, green: 0.07, blue: 0.07)
      if let artwork {
        Image(uiImage: artwork)
          .resizable()
          .scaledToFill()
          .blur(radius: 18)
          .opacity(0.55)
      }
    }
  }
}

struct NowPlayingArtwork: View {
  let artwork: UIImage?

  var body: some View {
    Group {
      if let artwork {
        Image(uiImage: artwork)
          .resizable()
          .scaledToFill()
      } else {
        Image(systemName: "music.note")
          .font(.title)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.white.opacity(0.12))
      }
    }
    .frame(width: 96, height: 96)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

struct NowPlayingTitles: View {
  let entry: NowPlayingEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(entry.title)
        .font(.headline)
        .lineLimit(2)
      if let message = entry.message, !message.isEmpty {
        Text(message)
          .font(.caption)
          .opacity(0.75)
          .lineLimit(1)
      }
    }
  }
}

struct NowPlayingControls: View {
  let entry: NowPlayingEntry
  let showsFavourite: Bool

  var body: some View {
    HStack(spacing: 0) {
      NowPlayingButton(action: .previous, systemImage: "backward.fill")
      Spacer(minLength: 0)
      NowPlayingButton(action: .playPause, systemImage: entry.isPlaying ? "pause.fill" : "play.fill")
      Spacer(minLength: 0)
      NowPlayingButton(action: .next, systemImage: "forward.fill")
      if showsFavourite {
        Spacer(minLength: 0)
        NowPlayingButton(action: .favourite, systemImage: entry.isFavourite ? "heart.fill" : "heart")
      }
    }
  }
}

struct NowPlayingButton: View {
  let action: NamidaMediaIntent.Action
  let systemImage: String

  var body: some View {
    Button(intent: NamidaMediaIntent(action)) {
      Image(systemName: systemImage)
        .font(.title3)
        .frame(width: 36, height: 36)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
