import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/complaint_response_sheet.dart';
import '../../../../core/widgets/kosmate_components.dart';
import '../../../../core/widgets/list_controls.dart';
import '../../../../models/complaint_model.dart';

class OwnerComplaintsSheet extends StatefulWidget {
  final int ownerId;

  const OwnerComplaintsSheet({super.key, required this.ownerId});

  @override
  State<OwnerComplaintsSheet> createState() => OwnerComplaintsSheetState();
}

class OwnerComplaintsSheetState extends State<OwnerComplaintsSheet> {
  final _complaintService = sl.complaint;
  final _searchController = TextEditingController();

  List<ComplaintModel> _allComplaints = [];
  List<ComplaintModel> _filteredComplaints = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  String _sortId = 'newest';
  int _page = 1;
  int _pageSize = 10;

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
      final complaints = await _complaintService.getComplaintsForOwner(
        widget.ownerId,
      );
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

  List<KosMateSortOption<ComplaintModel>> get _sortOptions => [
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
    KosMateSortOption<ComplaintModel>(
      id: 'room',
      label: 'Room # (A–Z)',
      comparator: (a, b) => (a.room?.roomNumber ?? '${a.roomId}')
          .toLowerCase()
          .compareTo((b.room?.roomNumber ?? '${b.roomId}').toLowerCase()),
    ),
  ];

  void _applyFilter() {
    var list = List<ComplaintModel>.from(_allComplaints);

    if (_selectedFilter == 'Open') {
      list = list.where((c) => c.status == ComplaintStatus.pending).toList();
    } else if (_selectedFilter == 'In Progress') {
      list = list.where((c) => c.status == ComplaintStatus.inProgress).toList();
    } else if (_selectedFilter == 'Resolved') {
      list = list.where((c) => c.status == ComplaintStatus.resolved).toList();
    } else if (_selectedFilter == 'Rejected') {
      list = list.where((c) => c.status == ComplaintStatus.rejected).toList();
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

    final selectedSort = _sortOptions.firstWhere(
      (s) => s.id == _sortId,
      orElse: () => _sortOptions.first,
    );
    list.sort(selectedSort.comparator);

    _filteredComplaints = list;
  }

  void _showComplaintResponseDialog(ComplaintModel complaint) {
    ComplaintResponseSheet.show(context, complaint, onUpdated: _loadComplaints);
  }

  @override
  Widget build(BuildContext context) {
    final paged = paginateList(_filteredComplaints, _page, _pageSize);
    final openCount = _allComplaints
        .where(
          (c) =>
              c.status == ComplaintStatus.pending ||
              c.status == ComplaintStatus.inProgress,
        )
        .length;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Complaints',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.foregroundColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: KosMateSearchField(
                  controller: _searchController,
                  hintText: 'Search by title, tenant, or room...',
                  fillColor: AppTheme.surfaceLight,
                  onChanged: (val) => setState(() {
                    _searchQuery = val.trim();
                    _page = 1;
                    _applyFilter();
                  }),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: KosMateFilterSortBar<ComplaintModel>(
                  filterOptions: const [
                    'All',
                    'Open',
                    'In Progress',
                    'Resolved',
                    'Rejected',
                  ],
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (val) => setState(() {
                    _selectedFilter = val;
                    _page = 1;
                    _applyFilter();
                  }),
                  sortOptions: _sortOptions,
                  selectedSortId: _sortId,
                  onSortChanged: (val) => setState(() {
                    _sortId = val;
                    _page = 1;
                    _applyFilter();
                  }),
                  totalCount: _filteredComplaints.length,
                  itemLabel:
                      '${_filteredComplaints.length == 1 ? 'complaint' : 'complaints'} ($openCount Open)',
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredComplaints.isEmpty
                    ? KosMateEmptyState(
                        icon: Icons.build_circle_outlined,
                        title: 'No complaints found',
                        subtitle: _selectedFilter != 'All'
                            ? 'No complaints match the "$_selectedFilter" filter.'
                            : 'Tenant maintenance tickets will appear here.',
                        plain: true,
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        itemCount: paged.pageItems.length,
                        itemBuilder: (context, index) {
                          final c = paged.pageItems[index];
                          final tenant = c.user?.name ?? 'Tenant';
                          final room = c.room?.roomNumber ?? 'Room ${c.roomId}';
                          final subtitle = '$tenant • $room';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: AppTheme.borderLight,
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
                                        color: AppTheme.iconBadgeBackground,
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
                                              color: AppTheme.textDark,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            subtitle,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textMuted,
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
              if (!_isLoading && _filteredComplaints.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: KosMatePaginationBar(
                    currentPage: paged.safePage,
                    totalPages: paged.totalPages,
                    totalItems: _filteredComplaints.length,
                    startIndex: paged.startIndex,
                    endIndex: paged.endIndex,
                    pageSize: _pageSize,
                    onPageChanged: (p) => setState(() => _page = p),
                    onPageSizeChanged: (s) => setState(() {
                      _pageSize = s;
                      _page = 1;
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
