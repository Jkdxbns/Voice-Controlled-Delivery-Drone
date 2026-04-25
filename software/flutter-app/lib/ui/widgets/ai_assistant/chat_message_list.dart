import 'package:flutter/material.dart';
import '../../../models/chat_message.dart';
import '../chat_bubble.dart';
import '../../../constants/constants.dart';

/// Chat message list widget
class ChatMessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final int? streamingMessageIndex;
  final ValueNotifier<String>? streamingContentNotifier;

  const ChatMessageList({
    super.key,
    required this.messages,
    required this.scrollController,
    this.streamingMessageIndex,
    this.streamingContentNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final iconSize = context.iconSize;
    final typography = context.typography;
    final colors = AppColorScheme.of(context);
    
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.emptyChat,
              size: iconSize.xxlarge,
              color: colors.textTertiary,
            ),
            SizedBox(height: spacing.large),
            Text(
              AppStrings.aiStartConversation,
              style: typography.titleMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
            SizedBox(height: spacing.small),
            Text(
              AppStrings.aiTypeOrRecord,
              style: typography.bodyMedium.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      primary: false,
      padding: EdgeInsets.symmetric(
        vertical: spacing.medium,
        horizontal: spacing.small,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isStreaming = index == streamingMessageIndex;

        return ChatBubble(
          key: ValueKey(message.id ?? 'temp_$index'),
          message: message,
          isStreaming: isStreaming,
          streamingContent: isStreaming ? streamingContentNotifier : null,
        );
      },
    );
  }
}
