import 'dart:async';

import 'package:flutter/material.dart';

import 'package:namico_subscription_manager/core/enum.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/party/party_connection.dart';
import 'package:namida/controller/party/party_controller.dart';
import 'package:namida/controller/party/party_protocol.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/pages/user/membership_card.dart';
import 'package:namida/youtube/pages/user/youtube_account_manage_page.dart';

part 'party/party_browse.dart';
part 'party/party_chat_section.dart';
part 'party/party_info_sections.dart';
part 'party/party_lobby.dart';
part 'party/party_privacy.dart';
part 'party/party_queue_section.dart';

class NamidaPartyPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_party;

  const NamidaPartyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: ObxO(
        rx: PartyController.inst.isActive,
        builder: (context, isActive) => isActive ? const _PartyActiveView() : const _PartyLobby(),
      ),
    );
  }
}

class _PartyActiveView extends StatefulWidget {
  const _PartyActiveView();

  @override
  State<_PartyActiveView> createState() => _PartyActiveViewState();
}

class _PartyActiveViewState extends State<_PartyActiveView> {
  final _chatController = TextEditingController();
  int _tabIndex = 0;

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Dimensions.inst.showSubpageInfoAtSideContext(context)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            flex: 5,
            child: _PartyInfoSections(),
          ),
          Expanded(
            flex: 6,
            child: _BottomPlayerPadding(
              child: Column(
                children: [
                  const Expanded(
                    flex: 3,
                    child: _PartyQueueSection(),
                  ),
                  Expanded(
                    flex: 2,
                    child: _PartyChatSection(
                      textController: _chatController,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return NamidaTabView(
      initialIndex: _tabIndex,
      reportIndexChangedOnInit: false,
      tabs: [lang.partyTabParty, lang.queue, lang.partyChat],
      onIndexChanged: (index) => _tabIndex = index,
      children: [
        const _PartyInfoSections(),
        const _BottomPlayerPadding(
          child: _PartyQueueSection(),
        ),
        _BottomPlayerPadding(
          child: _PartyChatSection(
            textController: _chatController,
          ),
        ),
      ],
    );
  }
}

class _BottomPlayerPadding extends StatelessWidget {
  final Widget child;

  const _BottomPlayerPadding({required this.child});

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final playerPadding = Dimensions.inst.globalBottomPaddingEffectiveR;
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardInset > playerPadding ? keyboardInset : playerPadding),
          child: child,
        );
      },
    );
  }
}
