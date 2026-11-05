import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// =============================================================================
// 1. STATUS BADGE CHIPS (Matches figma/Components.png)
// =============================================================================
enum KosMateChipType { paid, pending, open, active, occupied }

class KosMateStatusChip extends StatelessWidget {
  final String label;
  final KosMateChipType type;

  const KosMateStatusChip({
    super.key,
    required this.label,
    required this.type,
  });

  factory KosMateStatusChip.fromStatus(String status) {
    final lower = status.toLowerCase();
    if (lower == 'paid') {
      return const KosMateStatusChip(label: 'Paid', type: KosMateChipType.paid);
    } else if (lower == 'pending') {
      return const KosMateStatusChip(label: 'Pending', type: KosMateChipType.pending);
    } else if (lower == 'open' || lower == 'in_progress' || lower == 'inprogress') {
      return const KosMateStatusChip(label: 'Open', type: KosMateChipType.open);
    } else if (lower == 'occupied') {
      return const KosMateStatusChip(label: 'Occupied', type: KosMateChipType.occupied);
    } else {
      return KosMateStatusChip(label: status, type: KosMateChipType.active);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;

    switch (type) {
      case KosMateChipType.paid:
        bg = const Color(0xFFE6F4EA);
        text = const Color(0xFF137333);
        break;
      case KosMateChipType.pending:
        bg = const Color(0xFFFEF7E0);
        text = const Color(0xFFB06000);
        break;
      case KosMateChipType.open:
        bg = const Color(0xFFFDE8E8);
        text = const Color(0xFFC81E1E);
        break;
      case KosMateChipType.active:
        bg = const Color(0xFFEBF3FA);
        text = const Color(0xFF1E3A8A);
        break;
      case KosMateChipType.occupied:
        bg = const Color(0xFFEBF3FA);
        text = AppTheme.accentColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }
}

// =============================================================================
// 2. EMPTY STATE CARD (Matches figma/Components.png)
// =============================================================================
class KosMateEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;

  const KosMateEmptyState({
    super.key,
    this.icon = Icons.all_inbox_outlined,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF3FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0E1F3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: AppTheme.accentColor),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          if (buttonLabel != null && onButtonPressed != null) ...[
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(buttonLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// 3. ACTION BUTTONS (Matches figma/Components.png)
// =============================================================================
class KosMateButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isOutlined;
  final bool isDestructive;
  final bool isLoading;

  const KosMateButton.primary({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
  })  : isOutlined = false,
        isDestructive = false;

  const KosMateButton.outlined({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
  })  : isOutlined = true,
        isDestructive = false;

  const KosMateButton.destructive({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
  })  : isOutlined = false,
        isDestructive = true;

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.accentColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          minimumSize: const Size.fromHeight(48),
        ),
        child: isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: AppTheme.accentColor),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ],
              ),
      );
    }

    final Color bgColor = isDestructive ? const Color(0xFFB33A3A) : AppTheme.accentColor;

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size.fromHeight(48),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }
}

