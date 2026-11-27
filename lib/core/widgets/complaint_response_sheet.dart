import 'package:flutter/material.dart';

import '../constants/supabase_constants.dart';
import '../di/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../../models/complaint_model.dart';
import 'kosmate_components.dart';
import 'private_storage_image.dart';

/// Bottom sheet for Admin / Owner to inspect a complaint in full (matching
/// [TenantComplaintDetailDialog]) and respond / update its status.
class ComplaintResponseSheet extends StatefulWidget {
  final ComplaintModel complaint;
  final VoidCallback? onUpdated;

  const ComplaintResponseSheet({
    super.key,
    required this.complaint,
    this.onUpdated,
  });

  static Future<void> show(
    BuildContext context,
    ComplaintModel complaint, {
    VoidCallback? onUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) =>
          ComplaintResponseSheet(complaint: complaint, onUpdated: onUpdated),
    );
  }

  @override
  State<ComplaintResponseSheet> createState() => _ComplaintResponseSheetState();
}

class _ComplaintResponseSheetState extends State<ComplaintResponseSheet> {
  final _complaintService = sl.complaint;
  late final TextEditingController _responseCtrl;
  late ComplaintStatus _selectedStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _responseCtrl = TextEditingController(
      text: widget.complaint.response ?? '',
    );
    _selectedStatus = widget.complaint.status == ComplaintStatus.pending
        ? ComplaintStatus.inProgress
        : widget.complaint.status;
  }

  @override
  void dispose() {
    _responseCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _complaintService.respondToComplaint(
        complaintId: widget.complaint.complaintId,
        responseText: _responseCtrl.text.trim(),
        status: _selectedStatus,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated?.call();
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Complaint updated successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error updating complaint: $e'),
          backgroundColor: AppTheme.destructiveColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    final isOpen = c.status == ComplaintStatus.pending;
    final isResolved = c.status == ComplaintStatus.resolved;
    final attachmentPath = c.attachmentPath;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Complaint Detail & Response',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 16),

            // Banner tile
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isResolved
                    ? AppTheme.successLight
                    : (isOpen
                          ? AppTheme.destructiveLight
                          : AppTheme.warningLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.build_rounded,
                    color: isResolved
                        ? AppTheme.successColor
                        : (isOpen
                              ? AppTheme.destructiveColor
                              : AppTheme.warningColor),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isResolved
                                ? AppTheme.successColor
                                : (isOpen
                                      ? AppTheme.destructiveColor
                                      : AppTheme.warningColor),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.category.displayName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  KosMateStatusChip.fromComplaintStatus(c.status),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Complaint information',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRow('Submitted', Formatters.formatDate(c.date)),
                  const SizedBox(height: 8),
                  _buildRow('Priority', c.priority.displayName),
                  if (c.user != null) ...[
                    const SizedBox(height: 8),
                    _buildRow('Tenant', c.user!.name),
                  ],
                  const SizedBox(height: 8),
                  _buildRow(
                    'Room',
                    c.room != null
                        ? 'Room ${c.room!.roomNumber}'
                        : 'Room #${c.roomId}',
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppTheme.borderLight),
                  const SizedBox(height: 10),
                  Text(
                    c.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),

            if (attachmentPath != null && attachmentPath.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Attachment',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foregroundColor,
                ),
              ),
              const SizedBox(height: 8),
              PrivateStorageImage(
                bucketName: SupabaseConstants.complaintAttachmentsBucket,
                path: attachmentPath,
                height: 180,
              ),
            ],
            const SizedBox(height: 16),

            DropdownButtonFormField<ComplaintStatus>(
              isExpanded: true,
              initialValue: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Update Status',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: ComplaintStatus.values.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(
                    s.displayName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedStatus = val);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _responseCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Response / Action taken',
                hintText: 'e.g., Plumber has completed the repairs.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Response'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
