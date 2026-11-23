import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../models/complaint_model.dart';

class TenantComplaintDetailDialog extends StatelessWidget {
  final ComplaintModel complaint;

  const TenantComplaintDetailDialog({super.key, required this.complaint});

  static Future<void> show(BuildContext context, ComplaintModel complaint) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => TenantComplaintDetailDialog(complaint: complaint),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = complaint.status == ComplaintStatus.pending;
    final isResolved = complaint.status == ComplaintStatus.resolved;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
              'Complaint Detail',
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
                          complaint.title,
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
                        ),
                        const SizedBox(height: 2),
                        Text(
                          complaint.category.displayName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  KosMateStatusChip.fromComplaintStatus(complaint.status),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Complaint Information Card
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
                  _buildRow('Submitted', Formatters.formatDate(complaint.date)),
                  const SizedBox(height: 8),
                  _buildRow('Category', complaint.category.displayName),
                  const SizedBox(height: 8),
                  _buildRow('Priority', complaint.priority.displayName),
                  const SizedBox(height: 8),
                  _buildRow(
                    'Room',
                    complaint.room != null
                        ? 'Room ${complaint.room!.roomNumber}'
                        : 'Room #${complaint.roomId}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Description Card
            Container(
              width: double.infinity,
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
                    'Description',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    complaint.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textDark,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Owner response Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Owner response',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.foregroundColor,
                        ),
                      ),
                      Text(
                        complaint.response != null &&
                                complaint.response!.trim().isNotEmpty
                            ? 'Responded'
                            : 'Pending',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    complaint.response != null &&
                            complaint.response!.trim().isNotEmpty
                        ? complaint.response!
                        : 'No response yet. Your complaint is being reviewed by the property owner.',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          complaint.response != null &&
                              complaint.response!.trim().isNotEmpty
                          ? AppTheme.textDark
                          : AppTheme.textMuted,
                      fontStyle:
                          complaint.response != null &&
                              complaint.response!.trim().isNotEmpty
                          ? FontStyle.normal
                          : FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Back button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to complaints'),
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: AppTheme.accentColor,
                  side: const BorderSide(color: AppTheme.accentColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
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
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}
