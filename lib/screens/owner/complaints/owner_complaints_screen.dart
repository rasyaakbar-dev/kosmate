import 'package:flutter/material.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kosmate_app_bar.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../core/widgets/private_storage_image.dart';
import '../../../models/complaint_model.dart';
import '../../../models/user_model.dart';

class OwnerComplaintsScreen extends StatefulWidget {
  final UserModel owner;

  const OwnerComplaintsScreen({super.key, required this.owner});

  @override
  State<OwnerComplaintsScreen> createState() => _OwnerComplaintsScreenState();
}

class _OwnerComplaintsScreenState extends State<OwnerComplaintsScreen> {
  final _complaintService = sl.complaint;
  final _searchController = TextEditingController();

  List<ComplaintModel> _allComplaints = [];
  List<ComplaintModel> _filteredComplaints = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Tab filter: 0 = "All complaints", 1 = "Resolved"
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
      final complaints = await _complaintService.getComplaintsForOwner(
        widget.owner.userId,
      );
      if (mounted) {
        setState(() {
          _allComplaints = complaints;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter() {
    var list = List<ComplaintModel>.from(_allComplaints);

    if (_selectedFilterTab == 1) {
      list = list.where((c) => c.status == ComplaintStatus.resolved).toList();
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
    final attachmentPath = complaint.attachmentPath;
    ComplaintStatus selectedStatus = complaint.status == ComplaintStatus.pending
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
                  'Tenant: ${complaint.user?.name ?? "Tenant"} • Room: ${complaint.room?.roomNumber ?? complaint.roomId}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Description:\n${complaint.description}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                if (attachmentPath != null && attachmentPath.isNotEmpty) ...[
                  const Text(
                    'Attachment',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  PrivateStorageImage(
                    bucketName: SupabaseConstants.complaintAttachmentsBucket,
                    path: attachmentPath,
                    height: 180,
                  ),
                  const SizedBox(height: 16),
                ],
                DropdownButtonFormField<ComplaintStatus>(
                  isExpanded: true,
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                      value: ComplaintStatus.inProgress,
                      child: Text(
                        'In Progress',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    DropdownMenuItem(
                      value: ComplaintStatus.resolved,
                      child: Text(
                        'Resolved',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    DropdownMenuItem(
                      value: ComplaintStatus.rejected,
                      child: Text(
                        'Rejected',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
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
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final totalCount = _filteredComplaints.length;
    final openCount = _allComplaints
        .where(
          (c) =>
              c.status == ComplaintStatus.pending ||
              c.status == ComplaintStatus.inProgress,
        )
        .length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const KosMateAppBar(
        title: 'Complaints',
        showBackButton: true,
        showLogo: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadComplaints,
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedFilterTab = 0;
                                _applyFilter();
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedFilterTab == 0
                                    ? AppTheme.accentColor
                                    : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'All complaints',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedFilterTab == 0
                                      ? Colors.white
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedFilterTab = 1;
                                _applyFilter();
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedFilterTab == 1
                                    ? AppTheme.accentColor
                                    : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Resolved',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedFilterTab == 1
                                      ? Colors.white
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$totalCount complaints',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.destructiveLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$openCount Open',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.destructiveColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

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
                              vertical: 6,
                            ),
                            itemCount: _filteredComplaints.length,
                            itemBuilder: (context, index) {
                              final c = _filteredComplaints[index];
                              final tenant = c.user?.name ?? 'Tenant';
                              final room =
                                  c.room?.roomNumber ?? 'Room ${c.roomId}';
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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                ],
              ),
            ),
    );
  }
}
