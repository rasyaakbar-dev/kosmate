import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/complaint_model.dart';

class TenantAddComplaintDialog extends StatefulWidget {
  final int userId;
  final int roomId;
  final VoidCallback onSubmitted;

  const TenantAddComplaintDialog({
    super.key,
    required this.userId,
    required this.roomId,
    required this.onSubmitted,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int userId,
    required int roomId,
    required VoidCallback onSubmitted,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => TenantAddComplaintDialog(
        userId: userId,
        roomId: roomId,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  State<TenantAddComplaintDialog> createState() =>
      _TenantAddComplaintDialogState();
}

class _TenantAddComplaintDialogState extends State<TenantAddComplaintDialog> {
  final _complaintService = sl.complaint;
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  ComplaintCategory _selectedCategory = ComplaintCategory.maintenance;
  ComplaintPriority _selectedPriority = ComplaintPriority.medium;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      await _complaintService.createComplaint(
        userId: widget.userId,
        roomId: widget.roomId,
        category: _selectedCategory,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        priority: _selectedPriority,
      );

      widget.onSubmitted();
      nav.pop(true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Complaint submitted successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
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
                'Add Complaint',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foregroundColor,
                ),
              ),
              const SizedBox(height: 20),

              // Category
              _buildFieldLabel('Category'),
              const SizedBox(height: 6),
              DropdownButtonFormField<ComplaintCategory>(
                isExpanded: true,
                value: _selectedCategory,
                decoration: _inputDecoration(
                  hintText: 'Select category',
                  prefixIcon: Icons.category_outlined,
                ),
                items: ComplaintCategory.values.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(
                      c.displayName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 16),

              // Title
              _buildFieldLabel('Title'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter complaint title'
                    : null,
                decoration: _inputDecoration(
                  hintText: 'Enter complaint title',
                  prefixIcon: Icons.build_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // Description
              _buildFieldLabel('Description'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please describe your complaint in detail'
                    : null,
                decoration: _inputDecoration(
                  hintText: 'Describe your complaint in detail...',
                  prefixIcon: Icons.notes_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // Priority
              _buildFieldLabel('Priority'),
              const SizedBox(height: 6),
              DropdownButtonFormField<ComplaintPriority>(
                isExpanded: true,
                value: _selectedPriority,
                decoration: _inputDecoration(
                  hintText: 'Select priority',
                  prefixIcon: Icons.flag_outlined,
                ),
                items: ComplaintPriority.values.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(
                      p.displayName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPriority = val);
                },
              ),
              const SizedBox(height: 16),

              // Review Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Your complaint will be reviewed by the property owner and you will be notified once it is addressed.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accentColor,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: AppTheme.borderMedium),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_isSubmitting ? 'Submitting...' : 'Submit'),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textDark,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSubtle),
      prefixIcon: Icon(prefixIcon, color: AppTheme.textMuted, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.borderMedium),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.borderMedium),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.accentColor, width: 1.5),
      ),
    );
  }
}
