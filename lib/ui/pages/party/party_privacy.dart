part of '../party_page.dart';

/// english only, it is too long to translate & has to stay exact.
const _kPartyPrivacyNote = '''
No accounts, no tracking, and no audio ever leaves your device. Everyone plays their own copy.

The server only routes messages, it never reads them. The queue, playback and chat travel as opaque bytes, because every decision is made by the host device instead of the server.

While a room is open the server holds the room code, its options, the ban list, and for each member a display name, a device id and an IP address, used only for rate limiting and bans. All of it is deleted when the room ends: the host closes it, nobody is connected for 10 minutes, or 24 hours pass.

Others in the room see your name, the tracks you add (title, artist, album, duration, or a YouTube id, never the file or its path) and your chat messages. The host also sees your device id when approval is enabled. Nobody sees your IP.

Rooms are unlisted by default. A public room shows its name, member count and an anonymous host id to anyone browsing, and the current track only if you turn "Share what's playing" on.

Local network parties never reach any server, and the relay inside the app keeps everything in memory only.''';

void _showPartyPrivacyNote() {
  NamidaNavigator.inst.navigateDialog(
    dialog: CustomBlurryDialog(
      icon: Broken.shield_tick,
      title: lang.partyPrivacy,
      normalTitleStyle: true,
      actions: [
        NamidaButton(
          text: lang.learnMore,
          onTap: AppDocsLinks.PARTY_PRIVACY.launch,
        ),
        NamidaButton(
          text: lang.done,
          onTap: NamidaNavigator.inst.closeDialog,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Text(
          _kPartyPrivacyNote,
          style: namida.context?.theme.textTheme.displaySmall,
        ),
      ),
    ),
  );
}
