import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/kosmate_components.dart';
import '../../../../models/booking_model.dart';
import '../../../../models/complaint_model.dart';
import '../../../../models/house_model.dart';
import '../../../../models/payment_model.dart';
import '../../../../models/room_model.dart';
import '../../../../models/user_model.dart';

class UserDetailSectionHeader extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;

  const UserDetailSectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.accentColor, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.foregroundColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class UserDetailEmptyTile extends StatelessWidget {
  final String text;

  const UserDetailEmptyTile({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
      ),
    );
  }
}

class UserDetailBookingTile extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onTap;

  const UserDetailBookingTile({super.key, required this.booking, this.onTap});

  @override
  Widget build(BuildContext context) {
    final room = booking.room;
    final house = room?.house;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.meeting_room_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room ${room?.roomNumber ?? booking.roomId} - ${house?.houseName ?? "Boarding House"}',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foregroundColor,
                        ),
                      ),
                      Text(
                        'Status: ${booking.status.displayName} • Request: ${Formatters.formatDate(booking.requestDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (room != null)
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppTheme.textSubtle,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserDetailHouseTile extends StatelessWidget {
  final HouseModel house;
  final List<RoomModel> rooms;
  final VoidCallback onTap;

  const UserDetailHouseTile({
    super.key,
    required this.house,
    required this.rooms,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final availableCount = rooms
        .where((r) => r.status == RoomStatus.available)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.apartment_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        house.houseName,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foregroundColor,
                        ),
                      ),
                      Text(
                        house.houseAddress,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rooms.length} rooms • $availableCount available',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppTheme.textSubtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserDetailOwnerRoomTile extends StatelessWidget {
  final RoomModel room;
  final HouseModel house;
  final VoidCallback onTap;

  const UserDetailOwnerRoomTile({
    super.key,
    required this.room,
    required this.house,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.iconBadgeBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.meeting_room_outlined,
                    color: AppTheme.accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room ${room.roomNumber} • ${house.houseName}',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foregroundColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${room.roomType} • ${Formatters.formatCurrency(room.price)}/mo',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                KosMateStatusChip.fromRoomStatus(room.status),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppTheme.textSubtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserDetailPaymentTile extends StatelessWidget {
  final PaymentModel payment;
  final VoidCallback onTap;

  const UserDetailPaymentTile({
    super.key,
    required this.payment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (Color badgeBg, Color badgeText) = switch (payment.status) {
      PaymentStatus.paid => (AppTheme.successLight, AppTheme.successColor),
      PaymentStatus.pending => (AppTheme.warningLight, AppTheme.warningColor),
      PaymentStatus.overdue => (
        AppTheme.destructiveLight,
        AppTheme.destructiveColor,
      ),
      PaymentStatus.cancelled => (AppTheme.surfaceLight, AppTheme.textMuted),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.iconBadgeBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppTheme.accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            Formatters.formatCurrency(payment.amount),
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              payment.status.displayName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Due: ${Formatters.formatDate(payment.dueDate)} • Room ${payment.room?.roomNumber ?? payment.roomId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserDetailComplaintTile extends StatelessWidget {
  final ComplaintModel complaint;
  final VoidCallback onTap;

  const UserDetailComplaintTile({
    super.key,
    required this.complaint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (Color badgeBg, Color badgeText) = switch (complaint.status) {
      ComplaintStatus.resolved => (
        AppTheme.successLight,
        AppTheme.successColor,
      ),
      ComplaintStatus.inProgress => (
        AppTheme.warningLight,
        AppTheme.warningColor,
      ),
      ComplaintStatus.pending => (
        AppTheme.surfaceLight,
        AppTheme.primaryColor,
      ),
      ComplaintStatus.rejected => (
        AppTheme.destructiveLight,
        AppTheme.destructiveColor,
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.build_circle_outlined,
                    color: AppTheme.accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              complaint.title,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.foregroundColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              complaint.status.displayName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        complaint.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppTheme.textSubtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserRoleBadge extends StatelessWidget {
  final UserRole role;

  const UserRoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (role) {
      UserRole.admin => (
        AppTheme.destructiveLight,
        AppTheme.destructiveColor,
        'ADMIN',
      ),
      UserRole.owner => (
        AppTheme.warningLight,
        AppTheme.warningColor,
        'OWNER',
      ),
      UserRole.tenant => (
        AppTheme.primaryLight,
        AppTheme.primaryColor,
        'TENANT',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
