import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/list_controls.dart';
import '../../../core/widgets/owner_information_card.dart';
import '../../../models/booking_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/house_model.dart';
import '../../../models/user_model.dart';
import 'house_rooms_picker_screen.dart';
import 'widgets/tenant_my_room_view.dart';

class TenantRoomsTab extends StatefulWidget {
  final UserModel user;
  const TenantRoomsTab({super.key, required this.user});

  @override
  State<TenantRoomsTab> createState() => _TenantRoomsTabState();
}

class _TenantRoomsTabState extends State<TenantRoomsTab> {
  final _bookingService = sl.booking;
  final _houseService = sl.house;
  final _complaintService = sl.complaint;

  final _houseSearchController = TextEditingController();

  bool _isLoading = true;
  BookingModel? _activeBooking;
  BookingModel? _pendingBooking;
  List<ComplaintModel> _complaints = [];

  List<HouseModel> _houses = [];
  String _houseSearchQuery = '';
  String _houseFilter = 'All';
  String _houseSortId = 'name_asc';
  int _housePage = 1;
  int _housePageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _houseSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final bookings = await _bookingService.getBookingsByUser(
        widget.user.userId,
      );
      final active = bookings
          .where((b) => b.status == BookingStatus.approved)
          .firstOrNull;
      final pending = bookings
          .where((b) => b.status == BookingStatus.pending)
          .firstOrNull;

      List<ComplaintModel> complaints = [];
      if (active != null) {
        complaints = await _complaintService.getComplaintsByRoom(active.roomId);
      }

      List<HouseModel> houses = [];
      if (active == null) {
        houses = await _houseService.getAllHouses();
      }

      if (mounted) {
        setState(() {
          _activeBooking = active;
          _pendingBooking = pending;
          _complaints = complaints;
          _houses = houses;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCancelBooking(BookingModel booking) async {
    final eligibility = _bookingService.checkCancellationEligibility(booking);

    if (!eligibility.allowed) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.warningColor),
              SizedBox(width: 8),
              Text('Cancellation Policy'),
            ],
          ),
          content: Text(
            eligibility.reason ?? 'You cannot cancel your booking at this time according to house policy.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Room Booking?'),
        content: Text(
          'Are you sure you want to cancel your stay in Room ${booking.room?.roomNumber ?? ''}?\n\n'
          'Your room will be vacated and made available for other prospective tenants.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructiveColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _bookingService.cancelTenantBooking(booking: booking);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Your booking has been cancelled and room vacated.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadData();
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
      }
    }
  }

  Future<void> _handleCancelPendingRequest(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Request?'),
        content: const Text(
          'Do you want to cancel your pending room booking request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructiveColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _bookingService.updateBookingStatus(
          bookingId: booking.bookingId,
          status: BookingStatus.cancelled,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('Booking request withdrawn.')),
        );
        _loadData();
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeBooking != null && _activeBooking!.room != null) {
      return TenantMyRoomView(
        user: widget.user,
        booking: _activeBooking!,
        complaints: _complaints,
        onRefresh: _loadData,
        onCancelBooking: () => _handleCancelBooking(_activeBooking!),
      );
    }

    return _buildSearchAndPickHouseView();
  }

  Widget _buildSearchAndPickHouseView() {
    final houseSortOptions = [
      KosMateSortOption<HouseModel>(
        id: 'name_asc',
        label: 'Name (A–Z)',
        comparator: (a, b) =>
            a.houseName.toLowerCase().compareTo(b.houseName.toLowerCase()),
      ),
      KosMateSortOption<HouseModel>(
        id: 'name_desc',
        label: 'Name (Z–A)',
        comparator: (a, b) =>
            b.houseName.toLowerCase().compareTo(a.houseName.toLowerCase()),
      ),
      KosMateSortOption<HouseModel>(
        id: 'newest',
        label: 'Newest',
        comparator: (a, b) => b.houseId.compareTo(a.houseId),
      ),
    ];

    final filteredHouses = _houses.where((h) {
      if (_houseFilter == 'With Description' &&
          (h.description == null || h.description!.trim().isEmpty)) {
        return false;
      }
      if (_houseSearchQuery.isEmpty) return true;
      final q = _houseSearchQuery.toLowerCase();
      return h.houseName.toLowerCase().contains(q) ||
          h.houseAddress.toLowerCase().contains(q);
    }).toList();

    final selectedHouseSort = houseSortOptions.firstWhere(
      (s) => s.id == _houseSortId,
      orElse: () => houseSortOptions.first,
    );
    filteredHouses.sort(selectedHouseSort.comparator);

    final pagedHouses = paginateList(
      filteredHouses,
      _housePage,
      _housePageSize,
    );

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_pendingBooking != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.warningLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.warningColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.pending_actions_outlined,
                            color: AppTheme.warningColor,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Booking Request Pending',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppTheme.warningColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Room ${_pendingBooking!.room?.roomNumber ?? ""} • ${_pendingBooking!.room?.house?.houseName ?? "Boarding House"}\n'
                                  'The owner is reviewing your request.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _handleCancelPendingRequest(_pendingBooking!),
                            child: const Text(
                              'Withdraw',
                              style: TextStyle(
                                color: AppTheme.destructiveColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  KosMateSearchField(
                    controller: _houseSearchController,
                    hintText: 'Search boarding houses by name or address...',
                    onChanged: (val) => setState(() {
                      _houseSearchQuery = val.trim();
                      _housePage = 1;
                    }),
                  ),
                  const SizedBox(height: 10),

                  KosMateFilterSortBar<HouseModel>(
                    filterOptions: const ['All', 'With Description'],
                    selectedFilter: _houseFilter,
                    onFilterChanged: (val) => setState(() {
                      _houseFilter = val;
                      _housePage = 1;
                    }),
                    sortOptions: houseSortOptions,
                    selectedSortId: _houseSortId,
                    onSortChanged: (val) => setState(() {
                      _houseSortId = val;
                      _housePage = 1;
                    }),
                    totalCount: filteredHouses.length,
                    itemLabel: filteredHouses.length == 1 ? 'house' : 'houses',
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Boarding Houses',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (filteredHouses.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Icon(
                            Icons.home_work_outlined,
                            size: 48,
                            color: AppTheme.borderMedium,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No boarding houses match your search.',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pagedHouses.pageItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final house = pagedHouses.pageItems[index];
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppTheme.borderLight),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              final booked = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HouseRoomsPickerScreen(
                                    house: house,
                                    user: widget.user,
                                  ),
                                ),
                              );
                              if (booked == true) _loadData();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      color: AppTheme.borderLight,
                                      child:
                                          house.thumbnailUrl != null &&
                                              house.thumbnailUrl!
                                                  .trim()
                                                  .isNotEmpty
                                          ? Image.network(
                                              house.thumbnailUrl!.trim(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons.home_work_outlined,
                                                    color: AppTheme.textSubtle,
                                                  ),
                                            )
                                          : const Icon(
                                              Icons.home_work_outlined,
                                              color: AppTheme.textSubtle,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          house.houseName,
                                          style: const TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.foregroundColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          house.houseAddress,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textMuted,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        OwnerInformationCard(
                                          owner: house.owner,
                                          compact: true,
                                        ),
                                        const SizedBox(height: 8),
                                        const Row(
                                          children: [
                                            Text(
                                              'View Available Rooms',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.accentColor,
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 14,
                                              color: AppTheme.accentColor,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (filteredHouses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: KosMatePaginationBar(
                currentPage: pagedHouses.safePage,
                totalPages: pagedHouses.totalPages,
                totalItems: filteredHouses.length,
                startIndex: pagedHouses.startIndex,
                endIndex: pagedHouses.endIndex,
                pageSize: _housePageSize,
                onPageChanged: (p) => setState(() => _housePage = p),
                onPageSizeChanged: (s) => setState(() {
                  _housePageSize = s;
                  _housePage = 1;
                }),
              ),
            ),
        ],
      ),
    );
  }
}
