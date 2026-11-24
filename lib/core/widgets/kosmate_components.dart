import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../models/room_model.dart';
import '../../models/payment_model.dart';
import '../../models/complaint_model.dart';

/// Status chip types for rooms, payments, and complaints.
enum KosMateChipType {
  paid, // green
  pending, // amber
  open, // red
  active, // blue
  occupied, // blue
  available, // green
  repair, // amber  (maintenance / unavailable)
  inProgress, // amber
  resolved, // green
  rejected, // grey
  overdue, // red
  cancelled, // grey
}

class KosMateStatusChip extends StatelessWidget {
  final String label;
  final KosMateChipType type;

  const KosMateStatusChip({super.key, required this.label, required this.type});

  /// Factory constructor to derive status chip from a raw status string.
  factory KosMateStatusChip.fromStatus(String status) {
    final lower = status.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    switch (lower) {
      case 'paid':
        return const KosMateStatusChip(
          label: 'Paid',
          type: KosMateChipType.paid,
        );
      case 'pending':
        return const KosMateStatusChip(
          label: 'Pending',
          type: KosMateChipType.pending,
        );
      case 'open':
        return const KosMateStatusChip(
          label: 'Open',
          type: KosMateChipType.open,
        );
      case 'inprogress':
        return const KosMateStatusChip(
          label: 'In Progress',
          type: KosMateChipType.inProgress,
        );
      case 'resolved':
        return const KosMateStatusChip(
          label: 'Resolved',
          type: KosMateChipType.resolved,
        );
      case 'rejected':
        return const KosMateStatusChip(
          label: 'Rejected',
          type: KosMateChipType.rejected,
        );
      case 'overdue':
        return const KosMateStatusChip(
          label: 'Overdue',
          type: KosMateChipType.overdue,
        );
      case 'cancelled':
        return const KosMateStatusChip(
          label: 'Cancelled',
          type: KosMateChipType.cancelled,
        );
      case 'available':
        return const KosMateStatusChip(
          label: 'Available',
          type: KosMateChipType.available,
        );
      case 'repair':
      case 'maintenance':
      case 'unavailable':
        return const KosMateStatusChip(
          label: 'Repair',
          type: KosMateChipType.repair,
        );
      case 'occupied':
        return const KosMateStatusChip(
          label: 'Occupied',
          type: KosMateChipType.occupied,
        );
      default:
        return KosMateStatusChip(label: status, type: KosMateChipType.active);
    }
  }

  /// Type-safe named constructors
  factory KosMateStatusChip.fromRoomStatus(RoomStatus status) {
    switch (status) {
      case RoomStatus.available:
        return const KosMateStatusChip(
          label: 'Available',
          type: KosMateChipType.available,
        );
      case RoomStatus.occupied:
        return const KosMateStatusChip(
          label: 'Occupied',
          type: KosMateChipType.occupied,
        );
      case RoomStatus.maintenance:
      case RoomStatus.unavailable:
        return const KosMateStatusChip(
          label: 'Repair',
          type: KosMateChipType.repair,
        );
    }
  }

  factory KosMateStatusChip.fromPaymentStatus(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return const KosMateStatusChip(
          label: 'Paid',
          type: KosMateChipType.paid,
        );
      case PaymentStatus.pending:
        return const KosMateStatusChip(
          label: 'Pending',
          type: KosMateChipType.pending,
        );
      case PaymentStatus.overdue:
        return const KosMateStatusChip(
          label: 'Overdue',
          type: KosMateChipType.overdue,
        );
      case PaymentStatus.cancelled:
        return const KosMateStatusChip(
          label: 'Cancelled',
          type: KosMateChipType.cancelled,
        );
    }
  }

  factory KosMateStatusChip.fromComplaintStatus(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return const KosMateStatusChip(
          label: 'Open',
          type: KosMateChipType.open,
        );
      case ComplaintStatus.inProgress:
        return const KosMateStatusChip(
          label: 'In Progress',
          type: KosMateChipType.inProgress,
        );
      case ComplaintStatus.resolved:
        return const KosMateStatusChip(
          label: 'Resolved',
          type: KosMateChipType.resolved,
        );
      case ComplaintStatus.rejected:
        return const KosMateStatusChip(
          label: 'Rejected',
          type: KosMateChipType.rejected,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;

    switch (type) {
      case KosMateChipType.paid:
      case KosMateChipType.available:
      case KosMateChipType.resolved:
        bg = AppTheme.successLight;
        text = AppTheme.successColor;
        break;
      case KosMateChipType.pending:
      case KosMateChipType.inProgress:
      case KosMateChipType.repair:
        bg = AppTheme.warningLight;
        text = AppTheme.warningColor;
        break;
      case KosMateChipType.open:
      case KosMateChipType.overdue:
        bg = AppTheme.destructiveLight;
        text = AppTheme.destructiveColor;
        break;
      case KosMateChipType.active:
      case KosMateChipType.occupied:
        bg = AppTheme.primaryLight;
        text = AppTheme.accentColor;
        break;
      case KosMateChipType.rejected:
      case KosMateChipType.cancelled:
        bg = AppTheme.surfaceLight;
        text = AppTheme.textMuted;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
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

/// Search bar with bordered field and clear button.
class KosMateSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const KosMateSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderMedium, width: 1.2),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppTheme.textSubtle, fontSize: 14),
          prefixIcon: const Icon(
            Icons.search,
            color: AppTheme.textMuted,
            size: 20,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                  onPressed: () {
                    controller.clear();
                    onClear?.call();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

/// Empty state widget supporting both plain and card styles.
class KosMateEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;
  final bool plain; // If true, renders a simple centred column (no blue card)

  const KosMateEmptyState({
    super.key,
    this.icon = Icons.all_inbox_outlined,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButtonPressed,
    this.plain = false,
  });

  @override
  Widget build(BuildContext context) {
    if (plain) {
      // Simple centred column — matches existing list-screen empty state style
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 56, color: AppTheme.borderMedium),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSubtle,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Card variant
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
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
              color: AppTheme.textMuted,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(buttonLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Standard app button with primary, outlined, and destructive styles.
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
  }) : isOutlined = false,
       isDestructive = false;

  const KosMateButton.outlined({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
  }) : isOutlined = true,
       isDestructive = false;

  const KosMateButton.destructive({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
  }) : isOutlined = false,
       isDestructive = true;

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.accentColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          minimumSize: const Size.fromHeight(48),
        ),
        child: isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accentColor,
                ),
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

    final Color bgColor = isDestructive
        ? AppTheme.destructiveColor
        : AppTheme.accentColor;

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
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
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
