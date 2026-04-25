import 'package:flutter/material.dart';
import '../../constants/constants.dart';

/// UI helper functions for dialogs, popups, and alerts
class UiHelpers {
  /// Show error dialog
  static void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.actionOk),
          ),
        ],
      ),
    );
  }

  /// Show confirmation dialog
  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = AppStrings.actionOk,
    String cancelText = AppStrings.actionCancel,
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: confirmColor != null
                ? TextButton.styleFrom(foregroundColor: confirmColor)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Show centered floating popup (non-blocking, auto-dismisses)
  static void showCenteredPopup({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context);
    final spacing = context.spacing;
    final dimensions = context.dimensions;
    final iconSize = context.iconSize;
    final typography = context.typography;
    
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: ComponentSize.bottomSheetHandleHeight * 3,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: AppColors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.large,
                vertical: spacing.medium,
              ),
              margin: EdgeInsets.symmetric(horizontal: spacing.xlarge * 2),
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: AppOpacity.high),
                borderRadius: dimensions.borderRadiusMedium,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: AppOpacity.medium),
                    blurRadius: Spacing.medium,
                    spreadRadius: Spacing.xxsmall,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: iconSize.medium),
                  SizedBox(width: spacing.small),
                  Flexible(
                    child: Text(
                      message,
                      style: typography.bodyMedium.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeightStyle.medium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }

  /// Show input dialog for renaming
  static Future<String?> showRenameDialog({
    required BuildContext context,
    required String currentTitle,
  }) {
    final controller = TextEditingController(text: currentTitle);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.historyRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Chat Title',
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.actionCancel),
          ),
          TextButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.of(context).pop(newTitle);
              }
            },
            child: const Text(AppStrings.actionSave),
          ),
        ],
      ),
    );
  }
}
