// by claude
import SwiftUI
import WidgetKit

@main
struct NamidaWidgetsBundle: WidgetBundle {
  var body: some Widget {
    NowPlayingWidget()
    LyricsLiveActivity()
    if #available(iOS 18.0, *) {
      PlayPauseControl()
    }
  }
}
