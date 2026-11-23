import 'package:flutter/material.dart';

import '../../core/constants/supabase_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/kosmate_app_bar.dart';
import '../../core/widgets/kosmate_components.dart';
import '../../models/payment_model.dart';
import '../../models/room_model.dart';
import '../../models/user_model.dart';

class PaymentFormScreen extends StatefulWidget {
  final int? initialUserId;
  final int? initialRoomId;
  final PaymentModel? existingPayment;

  const PaymentFormScreen({
    super.key,
    this.initialUserId,
    this.initialRoomId,
    this.existingPayment,
  });

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _paymentService = sl.payment;
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();

  int? _selectedUserId;
  int? _selectedRoomId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  PaymentStatus _selectedStatus = PaymentStatus.pending;

  List<UserModel> _users = [];
  List<RoomModel> _rooms = [];
  bool _isLoadingInitial = true;
  bool _isSaving = false;

  bool get isEditMode => widget.existingPayment != null;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.existingPayment?.userId ?? widget.initialUserId;
    _selectedRoomId = widget.existingPayment?.roomId ?? widget.initialRoomId;
    if (widget.existingPayment != null) {
      _amountController.text = widget.existingPayment!.amount.toStringAsFixed(
        0,
      );
      _dueDate = widget.existingPayment!.dueDate;
      _selectedStatus = widget.existingPayment!.status;
    }
    _loadPrerequisites();
  }

  @override
  void dispose() {
    _amountController.dispose();
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
            if (!isEditMode && _amountController.text.isEmpty) {
              _amountController.text = rooms.first.price.toStringAsFixed(0);
            }
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

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (isEditMode) {
        await _paymentService.updatePaymentStatus(
          paymentId: widget.existingPayment!.paymentId,
          status: _selectedStatus,
        );
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Payment updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _paymentService.createPayment(
          userId: _selectedUserId!,
          roomId: _selectedRoomId!,
          amount: amount,
          dueDate: _dueDate,
        );
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Invoice issued successfully!'),
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
        title: isEditMode ? 'Edit Payment' : 'Issue Invoice',
        showBackButton: true,
        showLogo: false,
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
                      'Invoice Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _selectedUserId,
                      decoration: const InputDecoration(
                        labelText: 'Billed Tenant',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _users.map((u) {
                        return DropdownMenuItem(
                          value: u.userId,
                          child: Text(
                            '${u.name} (${u.email})',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
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
                      isExpanded: true,
                      initialValue: _selectedRoomId,
                      decoration: const InputDecoration(
                        labelText: 'Room',
                        prefixIcon: Icon(Icons.sensor_door_outlined),
                      ),
                      items: _rooms.map((r) {
                        final house = r.house?.houseName ?? 'Kos';
                        return DropdownMenuItem(
                          value: r.roomId,
                          child: Text(
                            'Room ${r.roomNumber} • $house',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: isEditMode
                          ? null
                          : (val) {
                              setState(() {
                                _selectedRoomId = val;
                                final room = _rooms.firstWhere(
                                  (r) => r.roomId == val,
                                );
                                _amountController.text = room.price
                                    .toStringAsFixed(0);
                              });
                            },
                      validator: (val) =>
                          val == null ? 'Please select a room' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Rent Amount (IDR)',
                        hintText: 'e.g. 1500000',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Enter amount';
                        }
                        if (double.tryParse(val.trim()) == null) {
                          return 'Must be a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    InkWell(
                      onTap: isEditMode
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _dueDate,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 30),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setState(() => _dueDate = picked);
                              }
                            },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Due Date',
                          prefixIcon: Icon(Icons.event_outlined),
                        ),
                        child: Text(
                          Formatters.formatDate(_dueDate),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isEditMode) ...[
                      DropdownButtonFormField<PaymentStatus>(
                        isExpanded: true,
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Payment Status',
                          prefixIcon: Icon(Icons.receipt_outlined),
                        ),
                        items: PaymentStatus.values.map((s) {
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
                          if (val != null) {
                            setState(() => _selectedStatus = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 28),
                    KosMateButton.primary(
                      label: _isSaving
                          ? 'Saving...'
                          : (isEditMode ? 'Update Payment' : 'Issue Invoice'),
                      onPressed: _isSaving ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
