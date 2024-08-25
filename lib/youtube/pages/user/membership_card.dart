import 'package:flutter/material.dart';

import 'package:namico_subscription_manager/core/enum.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';

class MembershipCard extends StatelessWidget {
  final bool displayName;
  const MembershipCard({super.key, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final containerColor = context.theme.colorScheme.secondaryContainer;
    final brL = 10.0.multipliedRadius;
    final brM = 8.0.multipliedRadius;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: containerColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(brL),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: containerColor.withOpacity(0.5),
            border: Border.all(
              color: containerColor,
            ),
            borderRadius: BorderRadius.circular(brM),
          ),
          child: ObxO(
            rx: YoutubeAccountController.membership.userSupabaseSub,
            builder: (context, userSupabaseSub) => ObxO(
              rx: YoutubeAccountController.membership.userPatreonTier,
              builder: (context, userPatreonTier) => ObxO(
                rx: YoutubeAccountController.membership.userMembershipTypeGlobal,
                builder: (context, userMembershipType) {
                  userMembershipType ??= MembershipType.unknown;
                  String text = userMembershipType.name.capitalizeFirst();
                  if (displayName) {
                    final username = userSupabaseSub?.name ?? userPatreonTier?.userName;
                    if (username != null && username.isNotEmpty) text += ' - $username';
                  }

                  Widget child = Text(
                    text,
                    style: context.textTheme.displayLarge,
                  );

                  if (userMembershipType == MembershipType.owner) {
                    child = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Broken.crown,
                          size: 20.0,
                        ),
                        const SizedBox(width: 8.0),
                        child,
                      ],
                    );
                  }

                  return child;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
