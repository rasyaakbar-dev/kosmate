import 'package:flutter/material.dart';

import '../../core/constants/supabase_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kosmate_app_bar.dart';
import '../../core/widgets/kosmate_components.dart';
import '../../models/complaint_model.dart';
import '../../models/room_model.dart';
import '../../models/user_model.dart';

class ComplaintFormScreen extends StatefulWidget {
  final int? initialUserId;
  final int? initialRoomId;
  final ComplaintModel? existingComplaint;

  const ComplaintFormScreen({
    super.key,
    this.initialUserId,
    this.initialRoomId,
    this.existingComplaint,
  });

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  final _complaintService = sl.complaint;
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _attachmentUrlController = TextEditingController();

  int? _selectedUserId;
  int? _selectedRoomId;
  ComplaintCategory _selectedCategory = ComplaintCategory.maintenance;
  ComplaintPriority _selectedPriority = ComplaintPriority.medium;
  ComplaintStatus _selectedStatus = ComplaintStatus.pending;

  List<UserModel> _users = [];
  List<RoomModel> _rooms = [];
  bool _isLoadingInitial = true;
  bool _isSaving = false;

  bool get isEditMode => widget.existingComplaint != null;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.existingComplaint?.userId ?? widget.initialUserId;
    _selectedRoomId = widget.existingComplaint?.roomId ?? widget.initialRoomId;
    if (widget.existingComplaint != null) {
      _titleController.text = widget.existingComplaint!.title;
      _descriptionController.text = widget.existingComplaint!.description;
      _attachmentUrlController.text =
          widget.existingComplaint!.attachmentUrl ?? '';
      _selectedCategory = widget.existingComplaint!.category;
      _selectedPriority = widget.existingComplaint!.priority;
      _selectedStatus = widget.existingComplaint!.status;
    }
    _loadPrerequisites();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _attachmentUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadPrerequisites() async {
    try {
      final usersRes = await supabase
          .from(SupabaseConstants.usersTable)
          .select();
      final users = (usersRes as List)
          .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
          .toList();

      final rooms = await sl.room.getRooms();

      if (mounted) {
        setState(() {
          _users = users;
          _rooms = rooms;
          if (_selectedUserId == null && users.isNotEmpty) {
            _selectedUserId = users.first.userId;
          }
          if (_selectedRoomId == null && rooms.isNotEmpty) {
            _selectedRoomId = rooms.first.roomId;
          }
          _isLoadingInitial = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null || _selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both a user and a room.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (isEditMode) {
        await _complaintService.respondToComplaint(
          complaintId: widget.existingComplaint!.complaintId,
          responseText: _descriptionController.text.trim(),
          status: _selectedStatus,
        );
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Complaint updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _complaintService.createComplaint(
          userId: _selectedUserId!,
          roomId: _selectedRoomId!,
          category: _selectedCategory,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _selectedPriority,
          attachmentUrl: _attachmentUrlController.text.trim().isEmpty
              ? null
              : _attachmentUrlController.text.trim(),
        );
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Complaint filed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KosMateAppBar(
        title: isEditMode ? 'Manage Ticket' : 'File Complaint Ticket',
        showBackButton: true,
        showLogo: false,
        showHelp: false,
      ),
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ticket Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<int>(
                      initialValue: _selectedUserId,
                      decoration: const InputDecoration(
                        labelText: 'Reporting Tenant',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _users.map((u) {
                        return DropdownMenuItem(
                          value: u.userId,
                          child: Text('${u.name} (${u.role.name})'),
                        );
                      }).toList(),
                      onChanged: isEditMode
                          ? null
                          : (val) => setState(() => _selectedUserId = val),
                      validator: (val) =>
                          val == null ? 'Please select a tenant' : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<int>(
                      initialValue: _selectedRoomId,
                      decoration: const InputDecoration(
                        labelText: 'Affected Room',
                        prefixIcon: Icon(Icons.sensor_door_outlined),
                      ),
                      items: _rooms.map((r) {
                        final house = r.house?.houseName ?? 'Kos';
                        return DropdownMenuItem(
                          value: r.roomId,
                          child: Text('Room ${r.roomNumber} • $house'),
                        );
                      }).toList(),
                      onChanged: isEditMode
                          ? null
                          : (val) => setState(() => _selectedRoomId = val),
                      validator: (val) =>
                          val == null ? 'Please select a room' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<ComplaintCategory>(
                            initialValue: _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: ComplaintCategory.values.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(c.displayName),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCategory = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<ComplaintPriority>(
                            initialValue: _selectedPriority,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              prefixIcon: Icon(Icons.priority_high_outlined),
                            ),
                            items: ComplaintPriority.values.map((p) {
                              return DropdownMenuItem(
                                value: p,
                                child: Text(p.displayName),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedPriority = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Ticket Title',
                        hintText: 'e.g. Broken AC in Room 102',
                        prefixIcon: Icon(Icons.title_outlined),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Please enter a title'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Detailed Description',
                        hintText: 'Describe the issue or action taken...',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Please enter a description'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    if (isEditMode) ...[
                      DropdownButtonFormField<ComplaintStatus>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Ticket Status',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
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
                            setState(() => _selectedStatus = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _attachmentUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Attachment / Photo URL (optional)',
                        hintText: 'https://...',
                        prefixIcon: Icon(Icons.attachment_outlined),
                      ),
                    ),
                    const SizedBox(height: 28),

                    KosMateButton.primary(
                      label: _isSaving
                          ? 'Saving...'
                          : (isEditMode ? 'Update Ticket' : 'Submit Complaint'),
                      onPressed: _isSaving ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
