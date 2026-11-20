import 'package:flutter/material.dart';

import '../../core/constants/supabase_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/kosmate_app_bar.dart';
import '../../core/widgets/kosmate_components.dart';
import '../../models/booking_model.dart';
import '../../models/room_model.dart';
import '../../models/user_model.dart';

class BookingFormScreen extends StatefulWidget {
  final int? initialUserId;
  final int? initialRoomId;
  final BookingModel? existingBooking;

  const BookingFormScreen({
    super.key,
    this.initialUserId,
    this.initialRoomId,
    this.existingBooking,
  });

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _bookingService = sl.booking;
  final _formKey = GlobalKey<FormState>();

  final _notesController = TextEditingController();

  int? _selectedUserId;
  int? _selectedRoomId;
  DateTime _requestDate = DateTime.now().add(const Duration(days: 1));
  BookingStatus _selectedStatus = BookingStatus.pending;

  List<UserModel> _users = [];
  List<RoomModel> _rooms = [];
  bool _isLoadingInitial = true;
  bool _isSaving = false;

  bool get isEditMode => widget.existingBooking != null;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.existingBooking?.userId ?? widget.initialUserId;
    _selectedRoomId = widget.existingBooking?.roomId ?? widget.initialRoomId;
    if (widget.existingBooking != null) {
      _requestDate = widget.existingBooking!.requestDate;
      _selectedStatus = widget.existingBooking!.status;
      _notesController.text = widget.existingBooking!.notes ?? '';
    }
    _loadPrerequisites();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPrerequisites() async {
    try {
      final usersRes = await supabase.from(SupabaseConstants.usersTable).select();
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
        await _bookingService.updateBookingStatus(
          bookingId: widget.existingBooking!.bookingId,
          status: _selectedStatus,
          roomId: _selectedRoomId,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('Booking updated successfully!'), backgroundColor: Colors.green),
        );
      } else {
        await _bookingService.createBooking(
          userId: _selectedUserId!,
          roomId: _selectedRoomId!,
          requestDate: _requestDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('Booking request created successfully!'), backgroundColor: Colors.green),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KosMateAppBar(
        title: isEditMode ? 'Edit Booking' : 'New Booking Request',
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
                      'Booking Information',
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
                        labelText: 'Tenant / User',
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
                      validator: (val) => val == null ? 'Please select a user' : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<int>(
                      initialValue: _selectedRoomId,
                      decoration: const InputDecoration(
                        labelText: 'Room',
                        prefixIcon: Icon(Icons.sensor_door_outlined),
                      ),
                      items: _rooms.map((r) {
                        final house = r.house?.houseName ?? 'Kos';
                        return DropdownMenuItem(
                          value: r.roomId,
                          child: Text('Room ${r.roomNumber} • $house (${Formatters.formatCurrency(r.price)})'),
                        );
                      }).toList(),
                      onChanged: isEditMode
                          ? null
                          : (val) => setState(() => _selectedRoomId = val),
                      validator: (val) => val == null ? 'Please select a room' : null,
                    ),
                    const SizedBox(height: 16),

                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _requestDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 180)),
                        );
                        if (picked != null) {
                          setState(() => _requestDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Desired Move-in Date',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(
                          Formatters.formatDate(_requestDate),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isEditMode) ...[
                      DropdownButtonFormField<BookingStatus>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Booking Status',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        items: BookingStatus.values.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(s.displayName),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedStatus = val);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'e.g. Move-in preferences, parking requirements...',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 28),

                    KosMateButton.primary(
                      label: _isSaving
                          ? 'Saving...'
                          : (isEditMode ? 'Update Booking' : 'Create Booking Request'),
                      onPressed: _isSaving ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
