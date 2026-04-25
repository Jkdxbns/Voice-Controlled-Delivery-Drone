import 'package:flutter/material.dart';
import '../../constants/constants.dart';

class HomeScreen extends StatelessWidget {
  final Function(int)? onNavigate;

  const HomeScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final dimensions = context.dimensions;
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          primary: false, // Don't use PrimaryScrollController
          padding: spacing.paddingLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tools Section
              _buildSectionHeader(context, AppStrings.navTools),
              SizedBox(height: spacing.medium),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: dimensions.gridColumnCount.clamp(1, 2),
                crossAxisSpacing: spacing.large,
                mainAxisSpacing: spacing.large,
                children: [
                  _buildTile(
                    context: context,
                    icon: AppIcons.ai,
                    title: AppStrings.navAiAssistant,
                    subtitle: AppStrings.homeSubtitleAi,
                    color: AppColors.tileAiAssistant,
                    onTap: () => onNavigate?.call(1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: context.typography.headingLarge.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final spacing = context.spacing;
    final dimensions = context.dimensions;
    final iconSize = context.iconSize;
    final typography = context.typography;
    
    return InkWell(
      onTap: onTap,
      borderRadius: dimensions.borderRadiusLarge,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: dimensions.borderRadiusLarge,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: AppOpacity.overlay),
            width: BorderSize.thin,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: spacing.paddingLarge,
              decoration: BoxDecoration(
                color: color.withValues(alpha: AppOpacity.hover),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize.xlarge,
                color: color,
              ),
            ),
            SizedBox(height: spacing.medium),
            Text(
              title,
              style: typography.titleMedium,
            ),
            SizedBox(height: spacing.xsmall),
            Text(
              subtitle,
              style: typography.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
