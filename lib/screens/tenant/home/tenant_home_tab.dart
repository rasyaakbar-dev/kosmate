import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/booking_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/user_model.dart';

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
          _activeBooking = bookings.isNotEmpty ? bookings.first : null;
          _latestPayment = payments.isNotEmpty ? payments.first : null;
          _latestComplaint = complaints.isNotEmpty ? complaints.first : null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNewComplaintDialog() {
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

    final titleController = TextEditingController();
    final descController = TextEditingController();
    ComplaintCategory selectedCategory = ComplaintCategory.maintenance;
    ComplaintPriority selectedPriority = ComplaintPriority.medium;

    final roomId = _activeBooking!.roomId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Submit Complaint (Room ${_activeBooking?.room?.roomNumber ?? roomId})',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ComplaintCategory>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ComplaintCategory.values.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c.displayName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedCategory = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ComplaintPriority>(
                  initialValue: selectedPriority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: ComplaintPriority.values.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text(p.displayName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedPriority = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Water leak',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _complaintService.createComplaint(
                    userId: widget.user.userId,
                    roomId: roomId,
                    category: selectedCategory,
                    title: titleController.text,
                    description: descController.text,
                    priority: selectedPriority,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadDashboardData();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Complaint submitted successfully!'),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasActiveRoom =
        _activeBooking != null && _activeBooking?.room != null;
    final roomNumber = hasActiveRoom
        ? _activeBooking!.room!.roomNumber
        : 'None';
    final houseName = hasActiveRoom
        ? (_activeBooking!.room!.house?.houseName ?? 'Boarding House')
        : 'Explore available rooms';
    final paymentStatus = _latestPayment != null
        ? _latestPayment!.status.displayName
        : 'No bills';
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
              hasActiveRoom
                  ? 'Room $roomNumber • $houseName'
                  : 'No active room • $houseName',
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF3FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD0E1F3)),
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
                                color: Color(0xFF475569),
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
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9E7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF9E8B5)),
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
                                color: Color(0xFF475569),
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
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
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
                  icon: Icons.bed_outlined,
                  label: 'My room',
                  onTap: () => widget.onNavigateToTab(1),
                ),
                const SizedBox(width: 10),
                _buildActionTile(
                  icon: Icons.mail_outline_rounded,
                  label: 'Payment',
                  onTap: () => widget.onNavigateToTab(2),
                ),
                const SizedBox(width: 10),
                _buildActionTile(
                  icon: Icons.feedback_outlined,
                  label: 'Complaint',
                  onTap: _showNewComplaintDialog,
                ),
                const SizedBox(width: 10),
                _buildActionTile(
                  icon: Icons.search_rounded,
                  label: 'Find Room',
                  onTap: () => widget.onNavigateToTab(1),
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
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
                              color: Color(0xFF64748B),
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
                            ? const Color(0xFFE6F4EA)
                            : const Color(0xFFFEF3D6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _latestPayment!.status.displayName,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _latestPayment!.status == PaymentStatus.paid
                              ? const Color(0xFF137333)
                              : Colors.orange[800],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_latestComplaint != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
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
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(label: Text(_latestComplaint!.status.displayName)),
                  ],
                ),
              ),
            ] else if (_latestPayment == null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No recent activities yet.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ),
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
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
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
