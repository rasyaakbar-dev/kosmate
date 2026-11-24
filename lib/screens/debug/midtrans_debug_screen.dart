import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/supabase_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/kosmate_components.dart';
import '../../models/payment_model.dart';
import '../../models/user_model.dart';
import '../../services/midtrans_service.dart';

class MidtransDebugScreen extends StatefulWidget {
  final UserModel currentUser;

  const MidtransDebugScreen({super.key, required this.currentUser});

  @override
  State<MidtransDebugScreen> createState() => _MidtransDebugScreenState();
}

class _MidtransDebugScreenState extends State<MidtransDebugScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _midtransService = sl.midtrans;
  final _paymentService = sl.payment;

  // Tab 1: Mock Charge State
  final _orderIdController = TextEditingController();
  final _amountController = TextEditingController(text: '10000');
  final _customerNameController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  bool _isCharging = false;
  MidtransChargeResponse? _lastChargeResponse;
  Map<String, dynamic>? _lastChargeRawJson;
  String? _chargeErrorMessage;

  // Tab 2: Status Check State
  final _statusOrderIdController = TextEditingController();
  bool _isCheckingStatus = false;
  bool _isCancelling = false;
  MidtransStatusResponse? _lastStatusResponse;
  Map<String, dynamic>? _lastStatusRawJson;
  String? _statusErrorMessage;

  // Tab 3: Real DB Payments State
  bool _isLoadingPayments = false;
  List<PaymentModel> _pendingDbPayments = [];
  String? _dbPaymentActionMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generateNewOrderId();

    _customerNameController.text = widget.currentUser.name.isNotEmpty
        ? widget.currentUser.name
        : 'Test User';
    _customerEmailController.text = widget.currentUser.email.isNotEmpty
        ? widget.currentUser.email
        : 'test@kosmate.local';
    _customerPhoneController.text = widget.currentUser.phone.isNotEmpty
        ? widget.currentUser.phone
        : '081234567890';

    _loadDbPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orderIdController.dispose();
    _amountController.dispose();
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _statusOrderIdController.dispose();
    super.dispose();
  }

  void _generateNewOrderId() {
    final newId = 'KOSMATE-DEBUG-${DateTime.now().millisecondsSinceEpoch}';
    _orderIdController.text = newId;
    _statusOrderIdController.text = newId;
  }

  Future<void> _loadDbPayments() async {
    setState(() => _isLoadingPayments = true);
    try {
      final payments = await _paymentService.getAllPayments();
      if (mounted) {
        setState(() {
          _pendingDbPayments = payments
              .where((p) => p.status == PaymentStatus.pending)
              .toList();
          _isLoadingPayments = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPayments = false);
      }
    }
  }

  // --- ACTIONS ---

  Future<void> _executeMockCharge() async {
    final orderId = _orderIdController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 10000;

    if (orderId.isEmpty) {
      _showToast('Order ID cannot be empty');
      return;
    }

    setState(() {
      _isCharging = true;
      _chargeErrorMessage = null;
    });

    try {
      final mockUser = UserModel(
        userId: widget.currentUser.userId,
        authId: widget.currentUser.authId,
        email: _customerEmailController.text.trim(),
        name: _customerNameController.text.trim(),
        phone: _customerPhoneController.text.trim(),
        role: widget.currentUser.role,
        createdAt: DateTime.now(),
      );

      final res = await _midtransService.chargeEWallet(
        orderId: orderId,
        grossAmount: amount,
        customer: mockUser,
      );

      // Also fetch raw json for full debug preview
      final raw = await _rawPostCharge(orderId, amount, mockUser);

      if (mounted) {
        setState(() {
          _lastChargeResponse = res;
          _lastChargeRawJson = raw;
          _statusOrderIdController.text = orderId;
          _isCharging = false;
        });
        _showToast('Charge initiated successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chargeErrorMessage = e.toString();
          _isCharging = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _rawPostCharge(
    String orderId,
    double amount,
    UserModel user,
  ) async {
    try {
      const key = MidtransConstants.serverKey;
      final auth = 'Basic ${base64Encode(utf8.encode('$key:'))}';
      final response = await http.post(
        Uri.parse('${MidtransConstants.baseUrl}/charge'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': auth,
        },
        body: jsonEncode({
          'payment_type': 'gopay',
          'transaction_details': {
            'order_id': orderId,
            'gross_amount': amount.round(),
          },
          'customer_details': {
            'first_name': user.name,
            'email': user.email,
            'phone': user.phone,
          },
          'gopay': {
            'enable_callback': true,
            'callback_url': 'kosmate://payment-finish',
          },
        }),
      );
      return jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkStatus() async {
    final orderId = _statusOrderIdController.text.trim();
    if (orderId.isEmpty) {
      _showToast('Enter an Order ID to check');
      return;
    }

    setState(() {
      _isCheckingStatus = true;
      _statusErrorMessage = null;
    });

    try {
      final res = await _midtransService.getTransactionStatus(orderId);

      // Fetch raw json for full status representation
      const key = MidtransConstants.serverKey;
      final auth = 'Basic ${base64Encode(utf8.encode('$key:'))}';
      final rawResp = await http.get(
        Uri.parse('${MidtransConstants.baseUrl}/$orderId/status'),
        headers: {'Accept': 'application/json', 'Authorization': auth},
      );
      Map<String, dynamic>? rawJson;
      try {
        rawJson = jsonDecode(rawResp.body) as Map<String, dynamic>?;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _lastStatusResponse = res;
          _lastStatusRawJson = rawJson;
          _isCheckingStatus = false;
        });
        _showToast('Status: ${res.transactionStatus}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusErrorMessage = e.toString();
          _isCheckingStatus = false;
        });
      }
    }
  }

  Future<void> _cancelTransaction() async {
    final orderId = _statusOrderIdController.text.trim();
    if (orderId.isEmpty) return;

    setState(() => _isCancelling = true);
    try {
      final success = await _midtransService.cancelTransaction(orderId);
      if (mounted) {
        setState(() => _isCancelling = false);
        _showToast(success ? 'Transaction cancelled!' : 'Cancel failed');
        // Refresh status
        _checkStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        _showToast('Cancel error: $e');
      }
    }
  }

  Future<void> _chargeDbPayment(PaymentModel payment) async {
    setState(() => _dbPaymentActionMessage = 'Initiating Midtrans charge...');
    try {
      final charged = await _paymentService.initiateMidtransPayment(
        payment: payment,
        tenant: widget.currentUser,
      );
      if (mounted) {
        setState(() {
          _statusOrderIdController.text = charged.orderId ?? '';
          _dbPaymentActionMessage =
              'Charged successfully! Order ID: ${charged.orderId}';
        });
        _loadDbPayments();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dbPaymentActionMessage = 'Error charging: $e');
      }
    }
  }

  Future<void> _syncDbPayment(PaymentModel payment) async {
    setState(() => _dbPaymentActionMessage = 'Syncing status with Midtrans...');
    try {
      final synced = await _paymentService.syncPaymentStatusWithMidtrans(
        payment,
      );
      if (mounted) {
        setState(() {
          _dbPaymentActionMessage = 'Synced! Status: ${synced.status.name}';
        });
        _loadDbPayments();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dbPaymentActionMessage = 'Error syncing: $e');
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showToast('$label copied to clipboard!');
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.developer_mode_rounded, color: AppTheme.accentColor),
            SizedBox(width: 8),
            Text(
              'Midtrans Debugger',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.flash_on_rounded), text: 'Charge'),
            Tab(icon: Icon(Icons.sync_rounded), text: 'Status & Cancel'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'DB Invoices'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildConfigHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChargeTab(),
                _buildStatusTab(),
                _buildDbInvoicesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.accentColor.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_done_rounded,
            color: AppTheme.accentColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target: ${MidtransConstants.baseUrl}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foregroundColor,
                  ),
                ),
                Text(
                  'Key: ${MidtransConstants.serverKey.substring(0, 12)}... (Sandbox)',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'SANDBOX',
              style: TextStyle(
                color: Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderMedium),
      ),
      child: child,
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppTheme.textSubtle,
              fontSize: 13,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderMedium),
            ),
          ),
        ),
      ],
    );
  }

  // --- TAB 1: CHARGE ---

  Widget _buildChargeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Charge Parameters',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  TextButton.icon(
                    onPressed: _generateNewOrderId,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('New ID'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInputField(
                controller: _orderIdController,
                label: 'Order ID',
                hint: 'KOSMATE-DEBUG-12345678',
              ),
              const SizedBox(height: 12),
              _buildInputField(
                controller: _amountController,
                label: 'Gross Amount (IDR)',
                hint: '10000',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: _customerNameController,
                      label: 'Customer Name',
                      hint: 'Test User',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInputField(
                      controller: _customerPhoneController,
                      label: 'Phone',
                      hint: '08123456789',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInputField(
                controller: _customerEmailController,
                label: 'Email',
                hint: 'test@kosmate.local',
              ),
              const SizedBox(height: 16),
              KosMateButton.primary(
                label: _isCharging
                    ? 'Executing Charge...'
                    : 'Charge GoPay / QRIS',
                icon: Icons.bolt_rounded,
                isLoading: _isCharging,
                onPressed: _isCharging ? null : _executeMockCharge,
              ),
            ],
          ),
        ),

        if (_chargeErrorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorBox(_chargeErrorMessage!),
        ],

        if (_lastChargeResponse != null) ...[
          const SizedBox(height: 16),
          _buildChargeResultCard(_lastChargeResponse!),
        ],

        if (_lastChargeRawJson != null) ...[
          const SizedBox(height: 16),
          _buildJsonViewer('Raw Charge Response JSON', _lastChargeRawJson!),
        ],
      ],
    );
  }

  Widget _buildChargeResultCard(MidtransChargeResponse res) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Charge Succeeded',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  res.transactionStatus.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildDataRow('Status Message', res.statusMessage),
          _buildDataRow('Transaction ID', res.transactionId),
          _buildDataRow('Status Code', res.statusCode),
          _buildDataRow('Payment Type', res.paymentType),
          _buildDataRow(
            'Gross Amount',
            Formatters.formatCurrency(double.tryParse(res.grossAmount) ?? 0.0),
          ),

          if (res.qrCodeUrl != null) ...[
            const SizedBox(height: 16),
            const Text(
              'QRIS QR Code:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Image.network(
                  res.qrCodeUrl!,
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Text('Failed to load QR image'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () =>
                    _copyToClipboard(res.qrCodeUrl!, 'QR Code URL'),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text(
                  'Copy QR URL',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],

          if (res.deeplinkUrl != null) ...[
            const SizedBox(height: 8),
            const Text(
              'GoPay Deeplink URL:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      res.deeplinkUrl!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () =>
                      _copyToClipboard(res.deeplinkUrl!, 'Deeplink URL'),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          KosMateButton.outlined(
            label: 'Copy Order ID to Status Tab',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {
              _statusOrderIdController.text = res.orderId;
              _tabController.animateTo(1);
            },
          ),
        ],
      ),
    );
  }

  // --- TAB 2: STATUS & CANCEL ---

  Widget _buildStatusTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Check Transaction Status / Cancel',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _buildInputField(
                controller: _statusOrderIdController,
                label: 'Order ID to Inspect',
                hint: 'e.g. KOSMATE-DEBUG-12345678',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: KosMateButton.primary(
                      label: _isCheckingStatus ? 'Checking...' : 'Check Status',
                      icon: Icons.sync_rounded,
                      isLoading: _isCheckingStatus,
                      onPressed: _isCheckingStatus ? null : _checkStatus,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: KosMateButton.destructive(
                      label: _isCancelling ? 'Cancelling...' : 'Cancel Trans.',
                      icon: Icons.cancel_outlined,
                      isLoading: _isCancelling,
                      onPressed: _isCancelling ? null : _cancelTransaction,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (_statusErrorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorBox(_statusErrorMessage!),
        ],

        if (_lastStatusResponse != null) ...[
          const SizedBox(height: 16),
          _buildStatusResultCard(_lastStatusResponse!),
        ],

        if (_lastStatusRawJson != null) ...[
          const SizedBox(height: 16),
          _buildJsonViewer('Raw Status JSON', _lastStatusRawJson!),
        ],
      ],
    );
  }

  Widget _buildStatusResultCard(MidtransStatusResponse res) {
    Color statusColor = Colors.orange;
    if (res.isSettled) statusColor = Colors.green;
    if (res.isExpiredOrCancelled) statusColor = Colors.red;

    final amountNum = double.tryParse(res.grossAmount) ?? 0.0;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Status Inspection Result',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  res.transactionStatus.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildDataRow('Order ID', res.orderId),
          _buildDataRow('Transaction Status', res.transactionStatus),
          _buildDataRow('Status Message', res.statusMessage),
          _buildDataRow('Status Code', res.statusCode),
          _buildDataRow('Gross Amount', Formatters.formatCurrency(amountNum)),
          _buildDataRow('Payment Type', res.paymentType),
          _buildDataRow('Transaction Time', res.transactionTime),
          if (res.settlementTime != null)
            _buildDataRow('Settlement Time', res.settlementTime!),
        ],
      ),
    );
  }

  // --- TAB 3: REAL DB INVOICES ---

  Widget _buildDbInvoicesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Real Invoices (payment table)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _loadDbPayments,
                  ),
                ],
              ),
              const Text(
                'Select any pending invoice from your database to initiate or sync Midtrans on a real record.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),

        if (_dbPaymentActionMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _dbPaymentActionMessage!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],

        const SizedBox(height: 16),
        if (_isLoadingPayments)
          const Center(child: CircularProgressIndicator())
        else if (_pendingDbPayments.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No pending payments found in database.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
          )
        else
          ..._pendingDbPayments.map((p) => _buildDbPaymentItem(p)),
      ],
    );
  }

  Widget _buildDbPaymentItem(PaymentModel payment) {
    final hasMidtrans = payment.orderId != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Invoice #${payment.paymentId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                KosMateStatusChip.fromStatus(payment.status.name),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Amount: ${Formatters.formatCurrency(payment.amount)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.accentColor,
              ),
            ),
            Text(
              'Due Date: ${Formatters.formatDate(payment.dueDate)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            if (hasMidtrans) ...[
              const SizedBox(height: 6),
              Text(
                'Order ID: ${payment.orderId}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Divider(height: 18),
            Row(
              children: [
                if (!hasMidtrans)
                  Expanded(
                    child: KosMateButton.primary(
                      label: 'Charge Midtrans',
                      icon: Icons.bolt_rounded,
                      onPressed: () => _chargeDbPayment(payment),
                    ),
                  )
                else ...[
                  Expanded(
                    child: KosMateButton.outlined(
                      label: 'Sync Status',
                      icon: Icons.sync_rounded,
                      onPressed: () => _syncDbPayment(payment),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: KosMateButton.outlined(
                      label: 'Inspect Tab',
                      icon: Icons.visibility_outlined,
                      onPressed: () {
                        _statusOrderIdController.text = payment.orderId!;
                        _tabController.animateTo(1);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE COMPONENTS ---

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.redAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonViewer(String title, Map<String, dynamic> jsonMap) {
    const encoder = JsonEncoder.withIndent('  ');
    final formattedJson = encoder.convert(jsonMap);

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                onPressed: () => _copyToClipboard(formattedJson, title),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              formattedJson,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0xFF9CDCFE),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
