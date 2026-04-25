import 'package:flutter/material.dart';
import '../../../constants/constants.dart';

/// Displays the current STT and LM model information
class ModelInfoBar extends StatelessWidget {
  final String sttModel;
  final String lmModel;

  const ModelInfoBar({
    super.key,
    required this.sttModel,
    required this.lmModel,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final iconSize = context.iconSize;
    final typography = context.typography;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.medium,
        vertical: spacing.small,
      ),
      decoration: BoxDecoration(
        color: AppColors.modelInfoBarBackground,
        border: Border(
          bottom: BorderSide(
            color: AppColors.white.withValues(alpha: AppOpacity.subtle),
            width: BorderSize.thin,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.microphone,
            size: iconSize.small,
            color: AppColors.modelInfoSttHighlight,
          ),
          SizedBox(width: spacing.xsmall),
          Text(
            AppStrings.aiStt,
            style: typography.labelMedium.copyWith(
              fontWeight: FontWeightStyle.bold,
              color: AppColors.modelInfoLabel,
            ),
          ),
          Text(
            sttModel,
            style: typography.labelMedium.copyWith(
              color: AppColors.modelInfoSttHighlight,
              fontWeight: FontWeightStyle.bold,
            ),
          ),
          SizedBox(width: spacing.large),
          Icon(
            AppIcons.ai,
            size: iconSize.small,
            color: AppColors.modelInfoLmHighlight,
          ),
          SizedBox(width: spacing.xsmall),
          Text(
            'LM: ',
            style: typography.labelMedium.copyWith(
              fontWeight: FontWeightStyle.bold,
              color: AppColors.modelInfoLabel,
            ),
          ),
          Text(
            lmModel,
            style: typography.labelMedium.copyWith(
              color: AppColors.modelInfoLmHighlight,
              fontWeight: FontWeightStyle.bold,
            ),
          ),
        ],
      ),
    );
  }
}
