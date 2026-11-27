import 'package:flutter/material.dart';

import '../../../core/constants/room_facilities.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/list_controls.dart';
import '../../../core/widgets/owner_information_card.dart';
import '../../../core/widgets/room_facilities_selector.dart';
import '../../../core/widgets/zoomable_image.dart';
import '../../../models/booking_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/house_model.dart';
import '../../../models/room_model.dart';
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
  final _roomService = sl.room;
  final _complaintService = sl.complaint;

  final _houseSearchController = TextEditingController();
  final _roomSearchController = TextEditingController();
  final _minRentController = TextEditingController();
  final _maxRentController = TextEditingController();

  bool _isLoading = true;
  bool _searchRoomsDirectly = true;
  BookingModel? _activeBooking;
  BookingModel? _pendingBooking;
  List<ComplaintModel> _complaints = [];

  List<HouseModel> _houses = [];
  List<RoomModel> _availableRooms = [];
  Set<int> _houseIdsWithAvailableRooms = {};
  List<String> _selectedFacilities = [];
  String _houseSearchQuery = '';
  String _roomSearchQuery = '';
  String _houseFilter = 'All';
  String _houseSortId = 'name_asc';
  int _housePage = 1;
  int _housePageSize = 10;
  int _roomPage = 1;
  int _roomPageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _houseSearchController.dispose();
    _roomSearchController.dispose();
    _minRentController.dispose();
    _maxRentController.dispose();
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
      List<RoomModel> availableRooms = [];
      Set<int> houseIdsWithAvailableRooms = {};
      if (active == null) {
        houses = await _houseService.getAllHouses();
        if (houses.isNotEmpty) {
          availableRooms = await _roomService.getRooms(
            status: RoomStatus.available,
          );
          houseIdsWithAvailableRooms = availableRooms
              .map((room) => room.houseId)
              .toSet();
        }
      }

      if (mounted) {
        setState(() {
          _activeBooking = active;
          _pendingBooking = pending;
          _complaints = complaints;
          _houses = houses;
          _availableRooms = availableRooms;
          _houseIdsWithAvailableRooms = houseIdsWithAvailableRooms;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not load room data. Pull to refresh and retry.',
            ),
            backgroundColor: AppTheme.destructiveColor,
          ),
        );
      }
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

  Future<void> _openSearchedRoom(RoomModel room) async {
    final house = room.house;
    if (house == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('House details are unavailable for this room.'),
          backgroundColor: AppTheme.destructiveColor,
        ),
      );
      return;
    }

    final booked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseRoomsPickerScreen(
          house: house,
          user: widget.user,
          initialRoomId: room.roomId,
        ),
      ),
    );
    if (booked == true) _loadData();
  }

  bool get _hasInvalidRent {
    final minText = _minRentController.text.trim();
    final maxText = _maxRentController.text.trim();
    final minRent = double.tryParse(minText);
    final maxRent = double.tryParse(maxText);
    final minInvalid = minText.isNotEmpty && minRent == null;
    final maxInvalid = maxText.isNotEmpty && maxRent == null;
    final rangeInvalid =
        minRent != null && maxRent != null && minRent > maxRent;

    return minInvalid || maxInvalid || rangeInvalid;
  }

  List<RoomModel> _getFilteredRooms() {
    final minRent = double.tryParse(_minRentController.text.trim());
    final maxRent = double.tryParse(_maxRentController.text.trim());
    final selectedFacilities = _selectedFacilities
        .map((facility) => facility.toLowerCase())
        .toSet();

    if (_hasInvalidRent) return [];

    final filteredRooms = _availableRooms.where((room) {
      if (minRent != null && room.price < minRent) return false;
      if (maxRent != null && room.price > maxRent) return false;

      final house = room.house;
      if (_roomSearchQuery.isNotEmpty) {
        final query = _roomSearchQuery.toLowerCase();
        final roomMatches =
            room.roomNumber.toLowerCase().contains(query) ||
            room.roomType.toLowerCase().contains(query);
        final houseMatches =
            house?.houseName.toLowerCase().contains(query) == true ||
            house?.houseAddress.toLowerCase().contains(query) == true;
        if (!roomMatches && !houseMatches) return false;
      }

      final roomFacilities = RoomFacilities.parse(room.facilities)
          .map((facility) => facility.toLowerCase())
          .toSet();
      return selectedFacilities.every(roomFacilities.contains);
    }).toList();

    filteredRooms.sort((a, b) {
      final byPrice = a.price.compareTo(b.price);
      if (byPrice != 0) return byPrice;
      return a.roomNumber.toLowerCase().compareTo(b.roomNumber.toLowerCase());
    });

    return filteredRooms;
  }

  Widget _buildDirectRoomSearchSection(List<RoomModel> filteredRooms) {
    final minText = _minRentController.text.trim();
    final maxText = _maxRentController.text.trim();
    final minRent = double.tryParse(minText);
    final maxRent = double.tryParse(maxText);
    final minInvalid = minText.isNotEmpty && minRent == null;
    final maxInvalid = maxText.isNotEmpty && maxRent == null;
    final rangeInvalid =
        minRent != null && maxRent != null && minRent > maxRent;
    final pagedRooms = paginateList(filteredRooms, _roomPage, _roomPageSize);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Find an available room across all houses.',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 12),
        KosMateSearchField(
          controller: _roomSearchController,
          hintText: 'Search room, house, or address...',
          onChanged: (value) => setState(() {
            _roomSearchQuery = value.trim();
            _roomPage = 1;
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minRentController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Min monthly rent',
                  prefixText: 'Rp ',
                  errorText: minInvalid
                      ? 'Enter a valid amount'
                      : rangeInvalid
                      ? 'Must be below max'
                      : null,
                ),
                onChanged: (_) => setState(() => _roomPage = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _maxRentController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Max monthly rent',
                  prefixText: 'Rp ',
                  errorText: maxInvalid
                      ? 'Enter a valid amount'
                      : rangeInvalid
                      ? 'Must be above min'
                      : null,
                ),
                onChanged: (_) => setState(() => _roomPage = 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            _selectedFacilities.isEmpty
                ? 'Filter by facilities'
                : 'Facilities (${_selectedFacilities.length} selected)',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          children: [
            RoomFacilitiesSelector(
              selectedFacilities: _selectedFacilities,
              onChanged: (facilities) => setState(() {
                _selectedFacilities = facilities;
                _roomPage = 1;
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${filteredRooms.length} available ${filteredRooms.length == 1 ? 'room' : 'rooms'}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 10),
        if (_hasInvalidRent)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                'Fix the rent range to see matching rooms.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
          )
        else if (filteredRooms.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No available rooms match your search.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
          )
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pagedRooms.pageItems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _buildSearchedRoomCard(pagedRooms.pageItems[index]),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchedRoomCard(RoomModel room) {
    final house = room.house;
    final imageUrl = room.imageUrls.isNotEmpty
        ? room.imageUrls.first
        : house?.thumbnailUrl;
    final facilities = RoomFacilities.parse(room.facilities);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openSearchedRoom(room),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: imageUrl != null && imageUrl.trim().isNotEmpty
                          ? ZoomableImage(
                              imageProvider: NetworkImage(imageUrl.trim()),
                              child: Image.network(
                                imageUrl.trim(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.meeting_room_outlined,
                                  color: AppTheme.accentColor,
                                ),
                              ),
                            )
                          : Container(
                              color: AppTheme.primaryLight,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.meeting_room_outlined,
                                color: AppTheme.accentColor,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Room ${room.roomNumber} • ${room.roomType}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.foregroundColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          house?.houseName ?? 'Boarding house',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (house?.houseAddress case final address?)
                          Text(
                            address,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${Formatters.formatCurrency(room.price)} / month',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (facilities.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: facilities
                      .take(4)
                      .map(
                        (facility) => Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(facility),
                          padding: EdgeInsets.zero,
                        ),
                      )
                      .toList(),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _openSearchedRoom(room),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('View room'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      if (_houseFilter == 'Available rooms' &&
          !_houseIdsWithAvailableRooms.contains(h.houseId)) {
        return false;
      }
      if (_houseFilter == 'With photos' &&
          (h.thumbnailUrl == null || h.thumbnailUrl!.trim().isEmpty)) {
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
    final filteredRooms = _getFilteredRooms();
    final pagedRooms = paginateList(filteredRooms, _roomPage, _roomPageSize);

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

                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.search_rounded),
                          label: Text('Search rooms'),
                        ),
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.home_work_outlined),
                          label: Text('Browse houses'),
                        ),
                      ],
                      selected: {_searchRoomsDirectly},
                      onSelectionChanged: (selection) => setState(() {
                        _searchRoomsDirectly = selection.first;
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_searchRoomsDirectly)
                    _buildDirectRoomSearchSection(filteredRooms)
                  else ...[
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
                      filterOptions: const [
                        'All',
                        'Available rooms',
                        'With photos',
                      ],
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
                      itemLabel: filteredHouses.length == 1
                          ? 'house'
                          : 'houses',
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
                              side: const BorderSide(
                                color: AppTheme.borderLight,
                              ),
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
                                            ? ZoomableImage(
                                                imageProvider: NetworkImage(
                                                  house.thumbnailUrl!.trim(),
                                                ),
                                                child: Image.network(
                                                  house.thumbnailUrl!.trim(),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) =>
                                                      const Icon(
                                                        Icons
                                                            .home_work_outlined,
                                                        color:
                                                            AppTheme.textSubtle,
                                                      ),
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
                ],
              ),
            ),
          ),
          if (_searchRoomsDirectly &&
              !_hasInvalidRent &&
              filteredRooms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: KosMatePaginationBar(
                currentPage: pagedRooms.safePage,
                totalPages: pagedRooms.totalPages,
                totalItems: filteredRooms.length,
                startIndex: pagedRooms.startIndex,
                endIndex: pagedRooms.endIndex,
                pageSize: _roomPageSize,
                onPageChanged: (page) => setState(() => _roomPage = page),
                onPageSizeChanged: (size) => setState(() {
                  _roomPageSize = size;
                  _roomPage = 1;
                }),
              ),
            )
          else if (!_searchRoomsDirectly && filteredHouses.isNotEmpty)
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
