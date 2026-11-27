import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/kosmate_components.dart';
import '../../../../core/widgets/list_controls.dart';
import '../../../../core/widgets/owner_information_card.dart';
import '../../../../core/widgets/room_facilities_card.dart';
import '../../../../models/booking_model.dart';
import '../../../../models/complaint_model.dart';
import '../../../../models/user_model.dart';
import '../../complaints/tenant_add_complaint_sheet.dart';
import '../../complaints/tenant_complaint_detail_sheet.dart';

class TenantMyRoomView extends StatefulWidget {
  final UserModel user;
  final BookingModel booking;
  final List<ComplaintModel> complaints;
  final Future<void> Function() onRefresh;
  final VoidCallback onCancelBooking;

  const TenantMyRoomView({
    super.key,
    required this.user,
    required this.booking,
    required this.complaints,
    required this.onRefresh,
    required this.onCancelBooking,
  });

  @override
  State<TenantMyRoomView> createState() => _TenantMyRoomViewState();
}

class _TenantMyRoomViewState extends State<TenantMyRoomView> {
  final _complaintSearchController = TextEditingController();
  String _complaintFilter = 'All';
  String _complaintSearchQuery = '';
  String _complaintSortId = 'newest';
  int _complaintPage = 1;
  int _complaintPageSize = 5;

  @override
  void dispose() {
    _complaintSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final room = booking.room!;
    final house = room.house;
    final requestId = 'KM-RR-${booking.bookingId.toString().padLeft(4, '0')}';

    final complaintSortOptions = [
      KosMateSortOption<ComplaintModel>(
        id: 'newest',
        label: 'Newest',
        comparator: (a, b) => b.date.compareTo(a.date),
      ),
      KosMateSortOption<ComplaintModel>(
        id: 'oldest',
        label: 'Oldest',
        comparator: (a, b) => a.date.compareTo(b.date),
      ),
      KosMateSortOption<ComplaintModel>(
        id: 'priority',
        label: 'Priority (High–Low)',
        comparator: (a, b) => b.priority.index.compareTo(a.priority.index),
      ),
    ];

    final filteredComplaints = widget.complaints.where((c) {
      if (_complaintFilter == 'Open' && c.status != ComplaintStatus.pending) {
        return false;
      }
      if (_complaintFilter == 'In Progress' &&
          c.status != ComplaintStatus.inProgress) {
        return false;
      }
      if (_complaintFilter == 'Resolved' &&
          c.status != ComplaintStatus.resolved) {
        return false;
      }
      if (_complaintFilter == 'Rejected' &&
          c.status != ComplaintStatus.rejected) {
        return false;
      }

      if (_complaintSearchQuery.isNotEmpty) {
        final q = _complaintSearchQuery.toLowerCase();
        return c.title.toLowerCase().contains(q) ||
            c.description.toLowerCase().contains(q) ||
            c.category.displayName.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final selectedComplaintSort = complaintSortOptions.firstWhere(
      (s) => s.id == _complaintSortId,
      orElse: () => complaintSortOptions.first,
    );
    filteredComplaints.sort(selectedComplaintSort.comparator);

    final pagedComplaints = paginateList(
      filteredComplaints,
      _complaintPage,
      _complaintPageSize,
    );

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.iconBadgeBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.sensor_door_outlined,
                    color: AppTheme.accentColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room ${room.roomNumber}',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.foregroundColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${house?.houseName ?? "Boarding House"} • ${room.roomType}',
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
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Occupied',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.successColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Room information',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildInfoRow('Room type', room.roomType),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    'Monthly rent',
                    Formatters.formatCurrency(room.price),
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    'Request date',
                    Formatters.formatDate(booking.requestDate),
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow('Request ID', requestId),
                  const SizedBox(height: 10),
                  _buildInfoRow('Room ID', '#${room.roomId}'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Facilities',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 12),
            RoomFacilitiesCard(facilities: room.facilities),
            const SizedBox(height: 20),
            OwnerInformationCard(owner: house?.owner),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.borderColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'House rules',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    house?.description != null &&
                            house!.description!.trim().isNotEmpty
                        ? house.description!
                        : 'Quiet hours after 22:00. Keep shared areas clean. Guests must leave by 21:00.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textDark,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Maintenance & Complaints',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foregroundColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                KosMateHeaderActionButton(
                  icon: Icons.add,
                  label: 'Add ticket',
                  isTextButton: true,
                  onPressed: () {
                    TenantAddComplaintSheet.show(
                      context,
                      userId: widget.user.userId,
                      roomId: room.roomId,
                      onSubmitted: widget.onRefresh,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            KosMateSearchField(
              controller: _complaintSearchController,
              hintText: 'Search complaints by title or category...',
              onChanged: (val) => setState(() {
                _complaintSearchQuery = val;
                _complaintPage = 1;
              }),
            ),
            const SizedBox(height: 10),
            KosMateFilterSortBar<ComplaintModel>(
              filterOptions: const [
                'All',
                'Open',
                'In Progress',
                'Resolved',
                'Rejected',
              ],
              selectedFilter: _complaintFilter,
              onFilterChanged: (val) => setState(() {
                _complaintFilter = val;
                _complaintPage = 1;
              }),
              sortOptions: complaintSortOptions,
              selectedSortId: _complaintSortId,
              onSortChanged: (val) => setState(() {
                _complaintSortId = val;
                _complaintPage = 1;
              }),
              totalCount: filteredComplaints.length,
              itemLabel: filteredComplaints.length == 1
                  ? 'complaint'
                  : 'complaints',
            ),
            const SizedBox(height: 12),
            if (filteredComplaints.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'No complaints match your filter.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              )
            else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pagedComplaints.pageItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = pagedComplaints.pageItems[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: InkWell(
                      onTap: () => TenantComplaintDetailSheet.show(context, c),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.iconBadgeBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.build_outlined,
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
                                  c.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.foregroundColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  c.description,
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
                          KosMateStatusChip.fromComplaintStatus(c.status),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: AppTheme.textSubtle,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              KosMatePaginationBar(
                currentPage: pagedComplaints.safePage,
                totalPages: pagedComplaints.totalPages,
                totalItems: filteredComplaints.length,
                startIndex: pagedComplaints.startIndex,
                endIndex: pagedComplaints.endIndex,
                pageSize: _complaintPageSize,
                onPageChanged: (p) => setState(() => _complaintPage = p),
                onPageSizeChanged: (s) => setState(() {
                  _complaintPageSize = s;
                  _complaintPage = 1;
                }),
              ),
            ],
            const SizedBox(height: 36),
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(
                  Icons.exit_to_app_rounded,
                  color: AppTheme.destructiveColor,
                  size: 20,
                ),
                label: const Text(
                  'Cancel Booking / Vacate Room',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.destructiveColor,
                  ),
                ),
                onPressed: widget.onCancelBooking,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  side: const BorderSide(
                    color: AppTheme.destructiveColor,
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Note: Cancellation is restricted in the 1st month & near month-end.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSubtle),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.foregroundColor,
            ),
          ),
        ),
      ],
    );
  }
}
