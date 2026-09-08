import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

/// Color palette used by the catalog & consignment screens.
///
/// Values are sourced from [AppColors] (the app's existing theme)
/// so the product/consignment UI matches the rest of the application.
class CatalogColors {
  // Accents
  static const Color primaryAccent = AppColors.primaryGreen;
  static const Color primaryDark = AppColors.primaryDark;
  static const Color primaryLight = AppColors.primaryLight;
  static const Color primaryPale = AppColors.primaryPale;
  static const Color secondaryAction = AppColors.infoBlue;
  static const Color accentWarm = AppColors.accentOrange;

  // Backgrounds / surfaces
  static const Color neutralBackground = Color(0xFFF8FAFC);
  static const Color cardBorder = AppColors.borderGrey;
  static const Color surfaceWhite = AppColors.surfaceWhite;
  static const Color textDark = AppColors.textDark;
  static const Color textMuted = AppColors.textMuted;

  // Status palettes — soft, dark-text versions of the primary
  // accent and warm/error tones already used across the app.
  static const Color inStockBg = AppColors.primaryPale;
  static const Color inStockText = AppColors.primaryDark;
  static const Color activeBg = AppColors.primaryPale;
  static const Color activeText = AppColors.primaryDark;

  static const Color pendingBg = Color(0xFFFEF3C7);
  static const Color pendingText = Color(0xFF92400E);

  static const Color lowStockBg = Color(0xFFFEE2E2);
  static const Color lowStockText = AppColors.errorRed;
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.background,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
