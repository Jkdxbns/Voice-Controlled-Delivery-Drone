import 'package:flutter/material.dart';
import '../../../constants/constants.dart';

/// Message input field with send button
class MessageInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final VoidCallback onSend;
  final Widget trailingWidget;

  const MessageInputField({
    super.key,
    required this.controller,
    required this.hasText,
    required this.onSend,
    required this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final dimensions = context.dimensions;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.medium,
        vertical: spacing.small,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: AppOpacity.border),
            width: BorderSize.thin,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 5,
              minLines: 1,
              decoration: InputDecoration(
                hintText: AppStrings.aiTypeMessage,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppRadius.xlarge),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: spacing.medium,
                  vertical: spacing.small,
                ),
              ),
            ),
          ),
          SizedBox(width: spacing.small),
          hasText
              ? IconButton(
                  onPressed: onSend,
                  icon: Icon(AppIcons.send),
                  color: AppColors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.info,
                    shape: const CircleBorder(),
                    padding: spacing.all(Spacing.medium),
                  ),
                )
              : trailingWidget,
        ],
      ),
    );
  }
}
