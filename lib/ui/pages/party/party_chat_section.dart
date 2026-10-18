part of '../party_page.dart';

class _PartyChatSection extends StatefulWidget {
  final TextEditingController textController;

  const _PartyChatSection({required this.textController});

  @override
  State<_PartyChatSection> createState() => _PartyChatSectionState();
}

class _PartyChatSectionState extends State<_PartyChatSection> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    var text = widget.textController.text.trim();
    if (text.isEmpty) return;
    if (text.length > PartyLimits.maxChatLength) text = text.substring(0, PartyLimits.maxChatLength);
    PartyController.inst.sendChat(text);
    widget.textController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final controller = PartyController.inst;
    return Column(
      children: [
        Expanded(
          child: ObxO(
            rx: controller.chatTick,
            builder: (context, _) {
              final messages = controller.state.chat;
              final myN = controller.myN;
              final lastIndex = messages.length - 1;
              // -- reversed, so it sticks to the newest message while at the bottom
              return NamidaScrollbarWithController(
                child: (sc) => SuperSmoothListView.builder(
                  controller: sc,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages.elementAt(lastIndex - index);
                    return _ChatBubble(
                      message: message,
                      isMine: message.n == myN,
                    );
                  },
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: ObxO(
            rx: controller.infoTick,
            builder: (context, _) => ObxO(
              rx: controller.membersTick,
              builder: (context, _) {
                final me = controller.me;
                if (me == null || !controller.state.canChat(me)) {
                  return NamidaText(
                    lang.partyChatDisabled,
                    style: NText.small,
                    textAlign: TextAlign.center,
                  );
                }
                return Row(
                  children: [
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: CustomTagTextField(
                        controller: widget.textController,
                        focusNode: _focusNode,
                        hintText: lang.partyChatHint,
                        labelText: '',
                        maxLines: 1,
                        onFieldSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    NamidaButton(
                      minHeight: NamidaButton.kDefaultMinHeight * 1.25,
                      minWidth: 64.0,
                      icon: Broken.send_2,
                      tooltip: () => lang.send,
                      onTap: _send,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final PartyChatMessage message;
  final bool isMine;

  const _ChatBubble({
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: NContainer(
        constraints: BoxConstraints(maxWidth: context.width * 0.7),
        margin: const EdgeInsets.symmetric(vertical: 3.0),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        decoration: (colors) => BoxDecoration(
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
          color: isMine ? colors.primary.withOpacityExt(0.2) : colors.card.withOpacityExt(0.6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              NamidaText(
                message.name,
                style: const NText(.small, size: .s11),
                color: NColors.primary,
              ),
            NamidaText(
              message.text,
              style: NText.medium,
            ),
          ],
        ),
      ),
    );
  }
}
