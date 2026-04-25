import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../constants/constants.dart';

/// Chat bubble widget (ChatGPT style) - Pure UI, no logic
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;
  final ValueNotifier<String>? streamingContent;

  const ChatBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.streamingContent,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColorScheme.of(context);
    final spacing = context.spacing;
    final dimensions = context.dimensions;
    final iconSize = context.iconSize;
    final typography = context.typography;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.small, horizontal: spacing.medium),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            // Avatar on left for assistant
            if (!isUser) ...[
              _buildAvatar(context, isDarkMode, isUser: false),
              SizedBox(width: spacing.small),
            ],
            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Role label
                  Text(
                    isUser ? 'You' : 'Assistant',
                    style: typography.caption.copyWith(
                      fontWeight: FontWeightStyle.bold,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: spacing.xsmall),
                  // Message text
                  Container(
                    padding: spacing.all(Spacing.medium),
                    decoration: BoxDecoration(
                      color: isUser 
                          ? (isDarkMode ? AppColorsDark.userBubble : AppColors.userBubble)
                          : (isDarkMode ? AppColorsDark.aiBubble : AppColors.aiBubble),
                      borderRadius: dimensions.borderRadiusMedium,
                      border: Border.all(
                        color: isUser 
                            ? (isDarkMode ? AppColorsDark.primary : AppColors.userBubbleBorder)
                            : (isDarkMode ? AppColorsDark.surface : AppColors.grey300),
                        width: BorderSize.thin,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Use ValueListenableBuilder for streaming content
                        if (isStreaming && streamingContent != null)
                          ValueListenableBuilder<String>(
                            valueListenable: streamingContent!,
                            builder: (context, content, _) {
                              return Text(
                                content.isEmpty ? message.content : content,
                                style: typography.bodySmall.copyWith(
                                  height: LineHeight.relaxed,
                                  color: isDarkMode ? AppColorsDark.textPrimary : AppColors.aiText,
                                ),
                              );
                            },
                          )
                        else
                          Text(
                            message.content,
                            style: typography.bodySmall.copyWith(
                              height: LineHeight.relaxed,
                              color: isDarkMode ? AppColorsDark.textPrimary : AppColors.aiText,
                            ),
                          ),
                        // Show streaming indicator for AI messages
                        if (isStreaming && !isUser) ...[
                          SizedBox(height: spacing.xsmall),
                          SizedBox(
                            width: iconSize.small,
                            height: iconSize.small,
                            child: CircularProgressIndicator(
                              strokeWidth: BorderSize.medium,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Model info (for AI messages)
                  if (!isUser && (message.sttModel != null || message.lmModel != null)) ...[
                    SizedBox(height: spacing.xsmall),
                    Text(
                      [
                        if (message.sttModel != null) 'STT: ${message.sttModel}',
                        if (message.lmModel != null) 'LM: ${message.lmModel}',
                      ].join(' | '),
                      style: typography.labelSmall.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Avatar on right for user
            if (isUser) ...[
              SizedBox(width: spacing.small),
              _buildAvatar(context, isDarkMode, isUser: true),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildAvatar(BuildContext context, bool isDarkMode, {required bool isUser}) {
    final spacing = context.spacing;
    final iconSize = context.iconSize;
    
    return CircleAvatar(
      radius: spacing.medium,
      backgroundColor: isDarkMode ? AppColorsDark.primary : (isUser ? AppColors.info : AppColors.grey300),
      child: Icon(
        isUser ? AppIcons.person : AppIcons.ai,
        size: iconSize.small,
        color: (isDarkMode || isUser) ? AppColors.white : AppColors.aiText,
      ),
    );
  }
}
