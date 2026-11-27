import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/booking_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/user_model.dart';
import '../complaints/tenant_add_complaint_sheet.dart';

class TenantHomeTab extends StatefulWidget {
  final UserModel user;
  final Function(int) onNavigateToTab;

  const TenantHomeTab({
    super.key,
    required this.user,
    required this.onNavigateToTab,
  });

  @override
  State<TenantHomeTab> createState() => _TenantHomeTabState();
}

class _TenantHomeTabState extends State<TenantHomeTab> {
  final _bookingService = sl.booking;
  final _paymentService = sl.payment;
  final _complaintService = sl.complaint;

  BookingModel? _activeBooking;
  BookingModel? _pendingBooking;
  PaymentModel? _latestPayment;
  ComplaintModel? _latestComplaint;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final bookings = await _bookingService.getBookingsByUser(
        widget.user.userId,
      );
      final payments = await _paymentService.getPaymentsByUser(
        widget.user.userId,
      );
      final complaints = await _complaintService.getComplaintsByUser(
        widget.user.userId,
      );

      if (mounted) {
        setState(() {
          // Identify approved active booking vs pending request
          _activeBooking = bookings
              .where((b) => b.status == BookingStatus.approved)
              .firstOrNull;
          _pendingBooking = bookings
              .where((b) => b.status == BookingStatus.pending)
              .firstOrNull;
          _latestPayment = payments.isNotEmpty ? payments.first : null;
          _latestComplaint = complaints.isNotEmpty ? complaints.first : null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNewComplaintSheet() {
    if (_activeBooking == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Active Room Booking'),
          content: const Text(
            'You do not have an approved room booking yet. Complaints can only be submitted once your room booking request has been approved by the owner.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    TenantAddComplaintSheet.show(
      context,
      userId: widget.user.userId,
      roomId: _activeBooking!.roomId,
      onSubmitted: _loadDashboardData,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasActiveRoom =
        _activeBooking != null && _activeBooking?.room != null;
    final hasPendingBooking =
        _pendingBooking != null && _pendingBooking?.room != null;

    final String roomNumber;
    final String subtitleLabel;
    final String paymentStatus;

    if (hasActiveRoom) {
      roomNumber = _activeBooking!.room!.roomNumber;
      final houseName =
          _activeBooking!.room!.house?.houseName ?? 'Boarding House';
      subtitleLabel = 'Room $roomNumber • $houseName';
      paymentStatus = _latestPayment != null
          ? _latestPayment!.status.displayName
          : 'No Bills';
    } else if (hasPendingBooking) {
      roomNumber = 'Pending';
      final houseName =
          _pendingBooking!.room!.house?.houseName ?? 'Boarding House';
      subtitleLabel =
          'Room ${_pendingBooking!.room!.roomNumber} • $houseName (Pending)';
      paymentStatus = 'Awaiting';
    } else {
      roomNumber = 'No Room';
      subtitleLabel = 'No room assigned • Explore boarding houses';
      paymentStatus = 'No Bills';
    }

    final greetingName = widget.user.name.trim().isNotEmpty
        ? widget.user.name.trim()
        : 'User';

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $greetingName!',
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitleLabel,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => widget.onNavigateToTab(1),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Room',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              Icon(
                                Icons.sensor_door_outlined,
                                color: AppTheme.accentColor,
                                size: 22,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            roomNumber,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: hasActiveRoom ? 24 : 18,
                              fontWeight: FontWeight.w700,
                              color: hasPendingBooking
                                  ? AppTheme.warningColor
                                  : AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => widget.onNavigateToTab(2),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.warningLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.warningLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Payment',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              Icon(
                                Icons.check_circle_outline_rounded,
                                color: AppTheme.accentColor,
                                size: 22,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            paymentStatus,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: hasActiveRoom ? 24 : 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Quick actions',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                _buildActionTile(
                  icon: hasActiveRoom
                      ? Icons.meeting_room_outlined
                      : (hasPendingBooking
                            ? Icons.pending_actions_outlined
                            : Icons.search_rounded),
                  label: hasActiveRoom
                      ? 'Room info'
                      : (hasPendingBooking ? 'My request' : 'Find Room'),
                  onTap: () => widget.onNavigateToTab(1),
                ),
                const SizedBox(width: 12),
                _buildActionTile(
                  icon: Icons.mail_outline_rounded,
                  label: 'Payment',
                  onTap: () => widget.onNavigateToTab(2),
                ),
                const SizedBox(width: 12),
                _buildActionTile(
                  icon: Icons.feedback_outlined,
                  label: 'Complaint',
                  onTap: _showNewComplaintSheet,
                ),
              ],
            ),
            const SizedBox(height: 26),

            const Text(
              'Recent information',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 12),

            if (_latestPayment != null) ...[
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => widget.onNavigateToTab(2),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.iconBadgeBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            color: AppTheme.accentColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Latest Invoice',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.foregroundColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${Formatters.formatCurrency(_latestPayment!.amount)} • Due: ${Formatters.formatDate(_latestPayment!.dueDate)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _latestPayment!.status == PaymentStatus.paid
                                ? AppTheme.successLight
                                : AppTheme.warningLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _latestPayment!.status.displayName,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  _latestPayment!.status == PaymentStatus.paid
                                  ? AppTheme.successColor
                                  : AppTheme.warningColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          color: AppTheme.textSubtle,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_latestComplaint != null) ...[
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(_latestComplaint!.title),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _latestComplaint!.description,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Category: ${_latestComplaint!.category.displayName}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textDark,
                              ),
                            ),
                            Text(
                              'Priority: ${_latestComplaint!.priority.displayName}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textDark,
                              ),
                            ),
                            Text(
                              'Status: ${_latestComplaint!.status.displayName}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textDark,
                              ),
                            ),
                            if (_latestComplaint!.response != null &&
                                _latestComplaint!.response!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Owner Response:\n${_latestComplaint!.response!}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.foregroundColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.iconBadgeBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: AppTheme.accentColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _latestComplaint!.title,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.foregroundColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _latestComplaint!.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _latestComplaint!.status.displayName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          color: AppTheme.textSubtle,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else if (_latestPayment == null) ...[
              if (!hasActiveRoom) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          color: AppTheme.accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Find your ideal room',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.textDark,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Browse available boarding houses and submit a booking request.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => widget.onNavigateToTab(1),
                        child: const Text('Browse'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No recent activities yet.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderMedium, width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppTheme.accentColor, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.foregroundColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
