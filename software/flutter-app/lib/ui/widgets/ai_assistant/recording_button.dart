import 'package:flutter/material.dart';
import '../../../constants/constants.dart';

enum ProcessingState {
  idle,
  recording,
  uploading,
  transcribing,
  processing,
  speaking,
}

/// Recording/Send button that changes based on state
class RecordingButton extends StatelessWidget {
  final ProcessingState processingState;
  final bool isRecording;
  final bool isTtsSpeaking;
  final VoidCallback? onMicPressed;
  final VoidCallback? onMicReleased;
  final VoidCallback? onStop;

  const RecordingButton({
    super.key,
    required this.processingState,
    required this.isRecording,
    required this.isTtsSpeaking,
    this.onMicPressed,
    this.onMicReleased,
    this.onStop,
  });

  IconData _getButtonIcon() {
    switch (processingState) {
      case ProcessingState.idle:
        return AppIcons.microphone;
      case ProcessingState.recording:
        return AppIcons.record;
      case ProcessingState.uploading:
        return AppIcons.cloudUpload;
      case ProcessingState.transcribing:
        return AppIcons.loading;
      case ProcessingState.processing:
        return AppIcons.ai;
      case ProcessingState.speaking:
        return AppIcons.volumeUp;
    }
  }

  Color _getButtonColor() {
    switch (processingState) {
      case ProcessingState.idle:
        return AppColors.info;
      case ProcessingState.recording:
        return AppColors.warning;
      case ProcessingState.uploading:
        return AppColors.orange;
      case ProcessingState.transcribing:
        return AppColors.purple;
      case ProcessingState.processing:
        return AppColors.success;
      case ProcessingState.speaking:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = context.iconSize;
    
    final bool canStop = processingState == ProcessingState.processing ||
        processingState == ProcessingState.speaking ||
        processingState == ProcessingState.transcribing ||
        processingState == ProcessingState.uploading ||
        isTtsSpeaking;

    return GestureDetector(
      onTapDown: canStop ? null : (_) => onMicPressed?.call(),
      onTapUp: canStop ? null : (_) => onMicReleased?.call(),
      onTapCancel: canStop ? null : () => onMicReleased?.call(),
      onTap: canStop ? onStop : null,
      child: Container(
        width: iconSize.xxlarge,
        height: iconSize.xxlarge,
        decoration: BoxDecoration(
          color: canStop ? AppColors.error : _getButtonColor(),
          shape: BoxShape.circle,
          boxShadow: isRecording || canStop
              ? [
                  BoxShadow(
                    color: (canStop ? AppColors.error : _getButtonColor())
                        .withValues(alpha: AppOpacity.medium),
                    blurRadius: Spacing.small,
                    spreadRadius: Spacing.xxsmall,
                  ),
                ]
              : null,
        ),
        child: Icon(
          canStop ? AppIcons.stop : _getButtonIcon(),
          color: AppColors.white,
          size: iconSize.xlarge,
        ),
      ),
    );
  }
}
