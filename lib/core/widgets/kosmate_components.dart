import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../models/room_model.dart';
import '../../models/payment_model.dart';
import '../../models/complaint_model.dart';

// =============================================================================
// 1. STATUS BADGE CHIPS (Matches figma/Components.png)
// =============================================================================
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

  // ---------------------------------------------------------------------------
  // String-based factory (backward compat)
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Type-safe named constructors
  // ---------------------------------------------------------------------------
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
        bg = const Color(0xFFE6F4EA);
        text = const Color(0xFF1E7E34);
        break;
      case KosMateChipType.pending:
      case KosMateChipType.inProgress:
      case KosMateChipType.repair:
        bg = const Color(0xFFFEF9E7);
        text = const Color(0xFFB45309);
        break;
      case KosMateChipType.open:
      case KosMateChipType.overdue:
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFB91C1C);
        break;
      case KosMateChipType.active:
      case KosMateChipType.occupied:
        bg = const Color(0xFFEBF3FA);
        text = const Color(0xFF1D4ED8);
        break;
      case KosMateChipType.rejected:
      case KosMateChipType.cancelled:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
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

// =============================================================================
// 2. SEARCH BAR (shared bordered TextField used in list screens)
// =============================================================================
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
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF64748B),
            size: 20,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
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

// =============================================================================
// 3. EMPTY STATE CARD (Matches figma/Components.png)
// =============================================================================
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
              Icon(icon, size: 56, color: const Color(0xFFCBD5E1)),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    }

    // Blue-card variant (original Figma design)
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
        ? const Color(0xFFB33A3A)
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
