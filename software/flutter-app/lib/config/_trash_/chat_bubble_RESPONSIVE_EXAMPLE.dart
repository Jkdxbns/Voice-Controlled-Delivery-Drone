import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../config/ui_config.dart';
import '../../config/responsive_config.dart';

/// Chat bubble widget (ChatGPT style) - RESPONSIVE VERSION EXAMPLE
/// 
/// This is a FULLY MIGRATED example showing how to convert from hardcoded
/// pixel values to responsive sizing using ResponsiveConfig.
/// 
/// Compare with chat_bubble.dart to see the before/after differences.
class ChatBubbleResponsive extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;
  final ValueNotifier<String>? streamingContent;

  const ChatBubbleResponsive({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.streamingContent,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // ✨ NEW: Get responsive config instance - this is the key to responsive design
    final responsive = context.responsive; // OR: ResponsiveConfig(context)

    return RepaintBoundary(
      child: Padding(
        // BEFORE: EdgeInsets.symmetric(vertical: UIConfig.spacingSmall, horizontal: UIConfig.spacingLarge)
        // AFTER: Use responsive padding
        padding: EdgeInsets.symmetric(
          vertical: responsive.spacingS,
          horizontal: responsive.spacingL,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            // Avatar on left for assistant
            if (!isUser) ...[
              _buildAvatar(context, isDarkMode, isUser: false),
              // BEFORE: SizedBox(width: UIConfig.spacingMedium)
              // AFTER: Use responsive spacing
              SizedBox(width: responsive.spacingM),
            ],
            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Role label
                  Text(
                    isUser ? 'You' : 'Assistant',
                    style: TextStyle(
                      // BEFORE: fontSize: UIConfig.fontSizeSmall (hardcoded 12.0)
                      // AFTER: Use responsive font size
                      fontSize: responsive.fontSizeS,
                      fontWeight: UIConfig.fontWeightBold,
                      color: isDarkMode ? UIConfig.colorGrey300 : UIConfig.colorGrey700,
                    ),
                  ),
                  // BEFORE: SizedBox(height: UIConfig.spacingSmall)
                  // AFTER: Use responsive spacing
                  SizedBox(height: responsive.spacingS),
                  // Message text
                  Container(
                    // BEFORE: padding: UIConfig.paddingAllMedium (hardcoded EdgeInsets.all(12.0))
                    // AFTER: Use responsive padding
                    padding: responsive.paddingM,
                    decoration: BoxDecoration(
                      color: isUser 
                          ? (isDarkMode ? UIConfig.colorUserBubbleDark : UIConfig.colorUserBubble)
                          : (isDarkMode ? UIConfig.colorAiBubbleDark : UIConfig.colorAiBubble),
                      // BEFORE: borderRadius: UIConfig.radiusMedium (hardcoded BorderRadius.circular(8.0))
                      // AFTER: Use responsive border radius
                      borderRadius: responsive.borderRadiusS,
                      border: Border.all(
                        color: isUser 
                            ? (isDarkMode ? UIConfig.colorDarkPrimary : UIConfig.colorUserBubbleBorder)
                            : (isDarkMode ? UIConfig.colorDarkSurface : UIConfig.colorGrey300),
                        // BEFORE: width: UIConfig.borderWidthThin (hardcoded 1.0)
                        // AFTER: Use responsive border width
                        width: responsive.borderWidthThin,
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
                                style: TextStyle(
                                  // BEFORE: fontSize: UIConfig.fontSizeSmall (hardcoded 12.0)
                                  // AFTER: Use responsive font size
                                  fontSize: responsive.fontSizeS,
                                  // BEFORE: height: 1.4 (hardcoded line height)
                                  // AFTER: Use responsive text style which has proper line height
                                  height: 1.4, // OR use responsive.textStyleBody
                                  color: isDarkMode ? UIConfig.colorGrey100 : UIConfig.colorAiText,
                                ),
                              );
                            },
                          )
                        else
                          Text(
                            message.content,
                            // ALTERNATIVE: Use predefined responsive text style
                            style: responsive.textStyleBody.copyWith(
                              color: isDarkMode ? UIConfig.colorGrey100 : UIConfig.colorAiText,
                            ),
                          ),
                        // Show streaming indicator for AI messages
                        if (isStreaming && !isUser) ...[
                          // BEFORE: SizedBox(height: UIConfig.spacingSmall)
                          // AFTER: Use responsive spacing
                          SizedBox(height: responsive.spacingS),
                          SizedBox(
                            // BEFORE: width/height: UIConfig.spacingMedium (hardcoded 12.0)
                            // AFTER: Use responsive spacing
                            width: responsive.spacingM,
                            height: responsive.spacingM,
                            child: CircularProgressIndicator(
                              // BEFORE: strokeWidth: UIConfig.borderWidthMedium (hardcoded 2.0)
                              // AFTER: Use responsive border width
                              strokeWidth: responsive.borderWidthMedium,
                              color: isDarkMode ? UIConfig.colorGrey300 : UIConfig.colorGrey600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Model info (for AI messages)
                  if (!isUser && (message.sttModel != null || message.lmModel != null)) ...[
                    // BEFORE: SizedBox(height: UIConfig.spacingSmall)
                    // AFTER: Use responsive spacing
                    SizedBox(height: responsive.spacingS),
                    Text(
                      [
                        if (message.sttModel != null) 'STT: ${message.sttModel}',
                        if (message.lmModel != null) 'LM: ${message.lmModel}',
                      ].join(' | '),
                      // BEFORE: UIConfig.textStyleTimestamp (uses hardcoded fontSizeSmall)
                      // AFTER: Use responsive text style
                      style: responsive.textStyleTimestamp.copyWith(
                        color: isDarkMode ? UIConfig.colorGrey400 : UIConfig.colorGrey600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Avatar on right for user
            if (isUser) ...[
              // BEFORE: SizedBox(width: UIConfig.spacingMedium)
              // AFTER: Use responsive spacing
              SizedBox(width: responsive.spacingM),
              _buildAvatar(context, isDarkMode, isUser: true),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildAvatar(BuildContext context, bool isDarkMode, {required bool isUser}) {
    // ✨ Get responsive config for avatar sizing
    final responsive = context.responsive;
    
    return CircleAvatar(
      // BEFORE: radius: UIConfig.spacingLarge (hardcoded 16.0)
      // AFTER: Use responsive spacing for avatar size
      radius: responsive.spacingL,
      backgroundColor: isDarkMode 
          ? UIConfig.colorDarkPrimary 
          : (isUser ? UIConfig.colorInfo : UIConfig.colorGrey300),
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        // BEFORE: size: UIConfig.iconSizeSmall (hardcoded 18.0)
        // AFTER: Use responsive icon size
        size: responsive.iconSizeS,
        color: (isDarkMode || isUser) ? UIConfig.colorWhite : UIConfig.colorAiText,
      ),
    );
  }
}