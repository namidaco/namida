// by claude
import AppIntents
import SwiftUI
import WidgetKit

/// a control center, lock screen & action button control.
@available(iOS 18.0, *)
struct PlayPauseControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: NamidaWidgetsShared.playPauseControlKind) {
      ControlWidgetButton(action: NamidaMediaIntent(.playPause)) {
        Label("Play/Pause", systemImage: "playpause.fill")
      }
    }
    .displayName("Namida play/pause")
    .description("Plays or pauses Namida.")
  }
}
