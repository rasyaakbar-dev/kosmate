import 'package:flutter/material.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kosmate_app_bar.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../core/widgets/private_storage_image.dart';
import '../../../models/payment_model.dart';
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';

class AdminPaymentFormScreen extends StatefulWidget {
  final PaymentModel? payment;
  final int? initialUserId;

  const AdminPaymentFormScreen({super.key, this.payment, this.initialUserId});

  bool get isEditing => payment != null;

  @override
  State<AdminPaymentFormScreen> createState() => _AdminPaymentFormScreenState();
}

class _AdminPaymentFormScreenState extends State<AdminPaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _paymentService = sl.payment;

  late final TextEditingController _amountController;

  int? _selectedUserId;
  int? _selectedRoomId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  DateTime? _paidDate;
  PaymentStatus _selectedStatus = PaymentStatus.pending;

  List<UserModel> _users = [];
  List<RoomModel> _rooms = [];
  bool _isLoadingPrerequisites = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.payment;
    _amountController = TextEditingController(
      text: p != null ? p.amount.toStringAsFixed(0) : '',
    );
    _selectedUserId = p?.userId ?? widget.initialUserId;
    _selectedRoomId = p?.roomId;
    if (p != null) {
      _dueDate = p.dueDate;
      _paidDate = p.paidDate;
      _selectedStatus = p.status;
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
      final users = await sl.user.getAllUsers();
      users.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

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
            if (!widget.isEditing && _amountController.text.isEmpty) {
              _amountController.text = rooms.first.price.toStringAsFixed(0);
            }
          }
          _isLoadingPrerequisites = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPrerequisites = false);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null || _selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a tenant and room.')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (widget.isEditing) {
        await _paymentService.updatePayment(
          paymentId: widget.payment!.paymentId,
          userId: _selectedUserId!,
          roomId: _selectedRoomId!,
          amount: amount,
          dueDate: _dueDate,
          status: _selectedStatus,
          paidDate: _selectedStatus == PaymentStatus.paid
              ? (_paidDate ?? DateTime.now())
              : null,
        );
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Payment updated successfully!'),
            backgroundColor: AppTheme.successColor,
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
            content: Text('Payment invoice created successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save payment: $e'),
          backgroundColor: AppTheme.destructiveColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDelete() async {
    if (!widget.isEditing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment'),
        content: const Text(
          'Are you sure you want to delete this payment record? This action cannot be undone.',
        ),
        actions: [
          KosMateCancelButton(
            isOutlined: false,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructiveColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _paymentService.deletePayment(widget.payment!.paymentId);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Payment deleted successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete payment: $e'),
          backgroundColor: AppTheme.destructiveColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receiptPath = widget.payment?.receiptPath;

    return Scaffold(
      appBar: KosMateAppBar(
        title: widget.isEditing ? 'Edit Payment' : 'Create Payment',
        showBackButton: true,
      ),
      body: _isLoadingPrerequisites
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Admin can directly inspect and change all fields.',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Tenant / User',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _selectedUserId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: AppTheme.textMuted,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.borderMedium,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.borderMedium,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _users.map((u) {
                        return DropdownMenuItem<int>(
                          value: u.userId,
                          child: Text(
                            '${u.name} (${u.email}) [${u.role.name}]',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedUserId = val),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Room',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _selectedRoomId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.meeting_room_outlined,
                          color: AppTheme.textMuted,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.borderMedium,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.borderMedium,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _rooms.map((r) {
                        final houseName =
                            r.house?.houseName ?? 'House #${r.houseId}';
                        return DropdownMenuItem<int>(
                          value: r.roomId,
                          child: Text(
                            'Room ${r.roomNumber} - $houseName (${Formatters.formatCurrency(r.price)})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedRoomId = val;
                          if (val != null) {
                            final match = _rooms.where((r) => r.roomId == val);
                            if (match.isNotEmpty && !widget.isEditing) {
                              _amountController.text = match.first.price
                                  .toStringAsFixed(0);
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Amount (Rp)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 1500000',
                        prefixIcon: const Icon(
                          Icons.attach_money,
                          color: AppTheme.textMuted,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.borderMedium,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.borderMedium,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Amount is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Due Date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _dueDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderMedium),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              Formatters.formatDate(_dueDate),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.foregroundColor,
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: AppTheme.textMuted,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Payment Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<PaymentStatus>(
                      value: _selectedStatus,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.flag_outlined,
                          color: AppTheme.textMuted,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.borderMedium,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.borderMedium,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: PaymentStatus.values.map((s) {
                        return DropdownMenuItem<PaymentStatus>(
                          value: s,
                          child: Text(s.displayName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedStatus = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    if (receiptPath != null && receiptPath.isNotEmpty) ...[
                      const Text(
                        'Private payment receipt',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      PrivateStorageImage(
                        bucketName: SupabaseConstants.paymentReceiptsBucket,
                        path: receiptPath,
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 28),

                    Row(
                      children: [
                        Expanded(
                          child: KosMateCancelButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _handleSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    widget.isEditing
                                        ? 'Save Changes'
                                        : 'Create Payment',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    if (widget.isEditing) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _handleDelete,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppTheme.destructiveColor,
                          ),
                          label: const Text(
                            'Delete Payment',
                            style: TextStyle(
                              color: AppTheme.destructiveColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppTheme.destructiveColor,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
