import 'package:flutter/material.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../models/booking_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/house_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';

// OwnerManagementHubTab — 3-segment operations hub:
//   0: Rooms & Renters (per-room summary cards)
//   1: Invoices & Payments (enhanced payment list)
//   2: Complaints (inline complaint management)
class OwnerManagementHubTab extends StatefulWidget {
  final UserModel user;

  const OwnerManagementHubTab({super.key, required this.user});

  @override
  State<OwnerManagementHubTab> createState() => _OwnerManagementHubTabState();
}

class _OwnerManagementHubTabState extends State<OwnerManagementHubTab> {
  int _selectedSegment = 0;

  static const _segmentLabels = [
    'Rooms & Renters',
    'Payments',
    'Complaints',
  ];

  static const _segmentIcons = [
    Icons.people_outline_rounded,
    Icons.receipt_long_outlined,
    Icons.build_circle_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
                Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: List.generate(_segmentLabels.length, (i) {
              final selected = _selectedSegment == i;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSegment = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primaryColor
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _segmentIcons[i],
                            size: 18,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _segmentLabels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

                Expanded(
          child: IndexedStack(
            index: _selectedSegment,
            children: [
              _RoomsRentersSegment(user: widget.user),
              _PaymentsSegment(user: widget.user),
              _ComplaintsSegment(user: widget.user),
            ],
          ),
        ),
      ],
    );
  }
}

// SEGMENT 0: Rooms & Renters
class _RoomsRentersSegment extends StatefulWidget {
  final UserModel user;

  const _RoomsRentersSegment({required this.user});

  @override
  State<_RoomsRentersSegment> createState() => _RoomsRentersSegmentState();
}

class _RoomsRentersSegmentState extends State<_RoomsRentersSegment> {
  final _houseService = sl.house;
  final _roomService = sl.room;
  final _complaintService = sl.complaint;

  bool _isLoading = true;

  List<HouseModel> _houses = [];

  // roomId → data maps
  Map<int, BookingModel> _bookingByRoom = {};
  Map<int, PaymentModel> _paymentByRoom = {};
  Map<int, List<ComplaintModel>> _complaintsByRoom = {};

  // flat ordered list of rooms (grouped by house)
  List<RoomModel> _rooms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final ownerId = widget.user.userId;

      final houses = await _houseService.getHousesByOwner(ownerId);

      final allRooms = <RoomModel>[];
      for (final h in houses) {
        final rooms = await _roomService.getRooms(houseId: h.houseId);
        allRooms.addAll(rooms);
      }

      // Bookings — query Supabase directly for all approved bookings for
      // rooms belonging to this owner
      final Map<int, BookingModel> bookingMap = {};
      if (allRooms.isNotEmpty) {
        try {
          final roomIds = allRooms.map((r) => r.roomId).toList();
          final bookingRes = await supabase
              .from(SupabaseConstants.bookingTable)
              .select('*, users!booking_user_id_fkey(*)')
              .inFilter('room_id', roomIds)
              .eq('status', BookingStatus.approved.name);
          for (final row in bookingRes as List) {
            final b = BookingModel.fromJson(row as Map<String, dynamic>);
            bookingMap[b.roomId] = b;
          }
        } catch (_) {}
      }

      // Payments
      final Map<int, PaymentModel> paymentMap = {};
      try {
        final payments = await sl.payment.getPaymentsForOwner(ownerId);
        // keep the latest (by dueDate) per room
        for (final p in payments) {
          final existing = paymentMap[p.roomId];
          if (existing == null) {
            paymentMap[p.roomId] = p;
          } else {
            if (p.dueDate.isAfter(existing.dueDate)) {
              paymentMap[p.roomId] = p;
            }
          }
        }
      } catch (_) {}

      // Complaints — open only
      final Map<int, List<ComplaintModel>> complaintsMap = {};
      try {
        final complaints =
            await _complaintService.getComplaintsForOwner(ownerId);
        for (final c in complaints) {
          if (c.status == ComplaintStatus.pending ||
              c.status == ComplaintStatus.inProgress) {
            complaintsMap.putIfAbsent(c.roomId, () => []).add(c);
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _houses = houses;
          _rooms = allRooms;
          _bookingByRoom = bookingMap;
          _paymentByRoom = paymentMap;
          _complaintsByRoom = complaintsMap;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_houses.isEmpty) {
      return const KosMateEmptyState(
        icon: Icons.apartment_outlined,
        title: 'No boarding houses yet',
        subtitle: 'Create a boarding house first from the Rooms tab.',
        plain: true,
      );
    }

    if (_rooms.isEmpty) {
      return const KosMateEmptyState(
        icon: Icons.sensor_door_outlined,
        title: 'No rooms yet',
        subtitle: 'Add rooms to your boarding houses from the Rooms tab.',
        plain: true,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _rooms.length,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          final booking = _bookingByRoom[room.roomId];
          final payment = _paymentByRoom[room.roomId];
          final openComplaints = _complaintsByRoom[room.roomId] ?? [];
          final houseName = room.house?.houseName ?? 'House';

          return _RoomRenterCard(
            room: room,
            houseName: houseName,
            booking: booking,
            payment: payment,
            openComplaints: openComplaints,
            onMarkPaid: payment != null &&
                    payment.status == PaymentStatus.pending
                ? () => _markPaid(payment)
                : null,
          );
        },
      ),
    );
  }

  Future<void> _markPaid(PaymentModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Mark invoice for ${p.user?.name ?? 'tenant'} '
          '(${Formatters.formatCurrency(p.amount)}) as paid?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm as Paid'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await sl.payment.updatePaymentStatus(
          paymentId: p.paymentId,
          status: PaymentStatus.paid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment marked as paid.'),
              backgroundColor: Colors.green,
            ),
          );
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      }
    }
  }
}

class _RoomRenterCard extends StatelessWidget {
  final RoomModel room;
  final String houseName;
  final BookingModel? booking;
  final PaymentModel? payment;
  final List<ComplaintModel> openComplaints;
  final VoidCallback? onMarkPaid;

  const _RoomRenterCard({
    required this.room,
    required this.houseName,
    required this.booking,
    required this.payment,
    required this.openComplaints,
    this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final tenantName = booking?.user?.name;
    final isVacant = room.status == RoomStatus.available;
    final paymentPeriod = payment != null
        ? Formatters.formatMonthYear(payment!.dueDate)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.1),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                        Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.roomNumber,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        houseName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                KosMateStatusChip.fromRoomStatus(room.status),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
            ),

                        Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isVacant
                        ? 'Vacant — no active renter'
                        : (tenantName ?? 'Renter assigned'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isVacant
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0F172A),
                      fontStyle:
                          isVacant ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

                        Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: payment == null
                      ? const Text(
                          'No invoice recorded',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$paymentPeriod • ${Formatters.formatCurrency(payment!.amount)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            KosMateStatusChip.fromPaymentStatus(
                              payment!.status,
                            ),
                          ],
                        ),
                ),
                if (onMarkPaid != null) ...[
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: onMarkPaid,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppTheme.accentColor,
                    ),
                    child: const Text(
                      'Mark Paid',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),

                        if (openComplaints.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${openComplaints.length} open: '
                      '"${openComplaints.first.title}"',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFB45309),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// SEGMENT 1: Invoices & Payments
class _PaymentsSegment extends StatefulWidget {
  final UserModel user;

  const _PaymentsSegment({required this.user});

  @override
  State<_PaymentsSegment> createState() => _PaymentsSegmentState();
}

class _PaymentsSegmentState extends State<_PaymentsSegment> {
  final _paymentService = sl.payment;
  final _searchController = TextEditingController();

  List<PaymentModel> _allPayments = [];
  List<PaymentModel> _filteredPayments = [];
  bool _isLoading = true;
  String _searchQuery = '';
  // 0=All, 1=Pending, 2=Paid, 3=Overdue
  int _statusFilter = 0;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final payments =
          await _paymentService.getPaymentsForOwner(widget.user.userId);
      if (mounted) {
        setState(() {
          _allPayments = payments;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    var list = List<PaymentModel>.from(_allPayments);

    if (_statusFilter == 1) {
      list = list.where((p) => p.status == PaymentStatus.pending).toList();
    } else if (_statusFilter == 2) {
      list = list.where((p) => p.status == PaymentStatus.paid).toList();
    } else if (_statusFilter == 3) {
      list = list.where((p) => p.status == PaymentStatus.overdue).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        final tenant = p.user?.name.toLowerCase() ?? '';
        final room = p.room?.roomNumber.toLowerCase() ?? '';
        return tenant.contains(q) || room.contains(q);
      }).toList();
    }

    _filteredPayments = list;
  }

  Future<void> _confirmPaymentPaid(PaymentModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Mark invoice #${p.paymentId} for '
          '${p.user?.name ?? "tenant"} '
          '(${Formatters.formatCurrency(p.amount)}) as paid?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm as Paid'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _paymentService.updatePaymentStatus(
          paymentId: p.paymentId,
          status: PaymentStatus.paid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment updated to Paid.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPayments();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Summary counts (from _allPayments, not filtered)
    final thisMonth = DateTime.now();
    final collectedAmt = _allPayments
        .where(
          (p) =>
              p.status == PaymentStatus.paid &&
              p.paidDate != null &&
              p.paidDate!.month == thisMonth.month &&
              p.paidDate!.year == thisMonth.year,
        )
        .fold<double>(0, (sum, p) => sum + p.amount);
    final pendingCount = _allPayments
        .where((p) => p.status == PaymentStatus.pending)
        .length;
    final overdueCount = _allPayments
        .where((p) => p.status == PaymentStatus.overdue)
        .length;

    return RefreshIndicator(
      onRefresh: _loadPayments,
      child: Column(
        children: [
          // Summary header card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF3FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD0E1F3)),
              ),
              child: Row(
                children: [
                  _buildSummaryItem(
                    'Collected',
                    Formatters.formatCurrency(collectedAmt),
                    Colors.green.shade700,
                  ),
                  _vDivider(),
                  _buildSummaryItem(
                    'Pending',
                    '$pendingCount invoices',
                    const Color(0xFFB45309),
                  ),
                  _vDivider(),
                  _buildSummaryItem(
                    'Overdue',
                    '$overdueCount invoices',
                    Colors.red.shade700,
                  ),
                ],
              ),
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in {
                    0: 'All',
                    1: 'Pending',
                    2: 'Paid',
                    3: 'Overdue',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(entry.value),
                        selected: _statusFilter == entry.key,
                        onSelected: (_) {
                          setState(() {
                            _statusFilter = entry.key;
                            _applyFilter();
                          });
                        },
                        selectedColor: AppTheme.accentColor.withAlpha(30),
                        checkmarkColor: AppTheme.accentColor,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _statusFilter == entry.key
                              ? AppTheme.accentColor
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Search input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: KosMateSearchBar(
              controller: _searchController,
              hintText: 'Search renter or room',
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                  _applyFilter();
                });
              },
              onClear: () {
                setState(() {
                  _searchQuery = '';
                  _applyFilter();
                });
              },
            ),
          ),

          // Count subtitle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              children: [
                Text(
                  '${_filteredPayments.length} payments',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Payments list
          Expanded(
            child: _filteredPayments.isEmpty
                ? const KosMateEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No payments found',
                    subtitle: 'Payment records will show here.',
                    plain: true,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: _filteredPayments.length,
                    itemBuilder: (context, index) {
                      final p = _filteredPayments[index];
                      final tenantName = p.user?.name ?? 'Tenant';
                      final roomNumber =
                          p.room?.roomNumber ?? 'Room ${p.roomId}';
                      final period = Formatters.formatMonthYear(
                        p.status == PaymentStatus.paid
                            ? p.paidDate
                            : p.dueDate,
                      );
                      final dateInfo = p.status == PaymentStatus.paid
                          ? (p.paidDate != null
                              ? 'Paid on ${Formatters.formatShortDate(p.paidDate)}'
                              : 'Paid')
                          : 'Due on ${Formatters.formatShortDate(p.dueDate)}';
                      final subtitle = '$roomNumber • $period • $dateInfo';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.1,
                          ),
                        ),
                        child: InkWell(
                          onTap: p.status == PaymentStatus.pending
                              ? () => _confirmPaymentPaid(p)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
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
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tenantName,
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        subtitle,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    KosMateStatusChip.fromPaymentStatus(
                                      p.status,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      Formatters.formatCurrency(p.amount),
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _vDivider() {
    return Container(
      height: 32,
      width: 1,
      color: const Color(0xFFCBD5E1),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// SEGMENT 2: Complaints
class _ComplaintsSegment extends StatefulWidget {
  final UserModel user;

  const _ComplaintsSegment({required this.user});

  @override
  State<_ComplaintsSegment> createState() => _ComplaintsSegmentState();
}

class _ComplaintsSegmentState extends State<_ComplaintsSegment> {
  final _complaintService = sl.complaint;
  final _searchController = TextEditingController();

  List<ComplaintModel> _allComplaints = [];
  List<ComplaintModel> _filteredComplaints = [];
  bool _isLoading = true;
  String _searchQuery = '';
  // 0=All, 1=Resolved
  int _selectedFilterTab = 0;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    try {
      final complaints =
          await _complaintService.getComplaintsForOwner(widget.user.userId);
      if (mounted) {
        setState(() {
          _allComplaints = complaints;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    var list = List<ComplaintModel>.from(_allComplaints);

    if (_selectedFilterTab == 1) {
      list =
          list.where((c) => c.status == ComplaintStatus.resolved).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) {
        final title = c.title.toLowerCase();
        final desc = c.description.toLowerCase();
        final tenant = c.user?.name.toLowerCase() ?? '';
        final room = c.room?.roomNumber.toLowerCase() ?? '';
        return title.contains(q) ||
            desc.contains(q) ||
            tenant.contains(q) ||
            room.contains(q);
      }).toList();
    }

    _filteredComplaints = list;
  }

  void _showComplaintResponseDialog(ComplaintModel complaint) {
    final responseCtrl = TextEditingController(text: complaint.response ?? '');
    ComplaintStatus selectedStatus =
        complaint.status == ComplaintStatus.pending
            ? ComplaintStatus.inProgress
            : complaint.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(complaint.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tenant: ${complaint.user?.name ?? "Tenant"} '
                  '• Room: ${complaint.room?.roomNumber ?? complaint.roomId}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Description:\n${complaint.description}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ComplaintStatus>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                      value: ComplaintStatus.inProgress,
                      child: Text('In Progress'),
                    ),
                    DropdownMenuItem(
                      value: ComplaintStatus.resolved,
                      child: Text('Resolved'),
                    ),
                    DropdownMenuItem(
                      value: ComplaintStatus.rejected,
                      child: Text('Rejected'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedStatus = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: responseCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Response / Action taken',
                    hintText: 'e.g., Plumber has completed the repairs.',
                  ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _complaintService.respondToComplaint(
                    complaintId: complaint.complaintId,
                    responseText: responseCtrl.text.trim(),
                    status: selectedStatus,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadComplaints();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Complaint updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Save'),
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

    final openCount = _allComplaints
        .where(
          (c) =>
              c.status == ComplaintStatus.pending ||
              c.status == ComplaintStatus.inProgress,
        )
        .length;

    return RefreshIndicator(
      onRefresh: _loadComplaints,
      child: Column(
        children: [
          const SizedBox(height: 10),

          // Filter tabs: All / Resolved
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterTab(0, 'All complaints'),
                const SizedBox(width: 10),
                _buildFilterTab(1, 'Resolved'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: KosMateSearchBar(
              controller: _searchController,
              hintText: 'Search complaints',
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                  _applyFilter();
                });
              },
              onClear: () {
                setState(() {
                  _searchQuery = '';
                  _applyFilter();
                });
              },
            ),
          ),

          // Count & open badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredComplaints.length} complaints',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (openCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$openCount Open',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _filteredComplaints.isEmpty
                ? KosMateEmptyState(
                    icon: Icons.build_circle_outlined,
                    title: 'No complaints found',
                    subtitle: _selectedFilterTab == 1
                        ? 'Resolved tickets will appear here.'
                        : 'Tenant maintenance tickets will appear here.',
                    plain: true,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: _filteredComplaints.length,
                    itemBuilder: (context, index) {
                      final c = _filteredComplaints[index];
                      final tenant = c.user?.name ?? 'Tenant';
                      final room =
                          c.room?.roomNumber ?? 'Room ${c.roomId}';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _showComplaintResponseDialog(c),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
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
                                    Icons.build_rounded,
                                    color: AppTheme.accentColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '$tenant • $room',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                KosMateStatusChip.fromComplaintStatus(
                                  c.status,
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppTheme.accentColor,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(int index, String label) {
    final selected = _selectedFilterTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilterTab = index;
            _applyFilter();
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accentColor : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}
