import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../models/payment_model.dart';
import '../../../services/payment_service.dart';

class MidtransPaymentSheet extends StatefulWidget {
  final PaymentModel payment;
  final VoidCallback onPaymentSuccess;

  const MidtransPaymentSheet({
    super.key,
    required this.payment,
    required this.onPaymentSuccess,
  });

  @override
  State<MidtransPaymentSheet> createState() => _MidtransPaymentSheetState();
}

class _MidtransPaymentSheetState extends State<MidtransPaymentSheet> {
  final _paymentService = PaymentService();
  late PaymentModel _currentPayment;
  bool _isCheckingStatus = false;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _currentPayment = widget.payment;
  }

  Future<void> _checkStatus() async {
    setState(() => _isCheckingStatus = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final updated = await _paymentService.syncPaymentStatusWithMidtrans(_currentPayment);
      if (!mounted) return;
      setState(() {
        _currentPayment = updated;
        _isCheckingStatus = false;
      });

      if (updated.status == PaymentStatus.paid) {
        widget.onPaymentSuccess();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text('Payment confirmed! Invoice is now PAID.'),
            ),
          );
        }
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Payment is still pending. Please scan or complete payment in GoPay/QRIS.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingStatus = false);
        messenger.showSnackBar(SnackBar(content: Text('Error checking status: $e')));
      }
    }
  }

  Future<void> _cancelPayment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Payment Session?'),
        content: const Text('This will cancel this Midtrans transaction. You can restart anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB33A3A)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      await _paymentService.cancelMidtransPayment(_currentPayment);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment transaction cancelled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _copyDeeplink() {
    if (_currentPayment.deeplinkUrl != null) {
      Clipboard.setData(ClipboardData(text: _currentPayment.deeplinkUrl!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GoPay payment link copied to clipboard!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrUrl = _currentPayment.qrCodeUrl;
    final orderId = _currentPayment.orderId ?? 'KOSMATE-INV-${_currentPayment.paymentId}';

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header title & close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GoPay / QRIS Payment',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foregroundColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Invoice summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF3FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payment',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                      ),
                      Text(
                        Formatters.formatCurrency(_currentPayment.amount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order ID', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      Text(
                        orderId,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // QR Code Section
            if (qrUrl != null && qrUrl.isNotEmpty) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Image.network(
                        qrUrl,
                        width: 210,
                        height: 210,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            width: 210,
                            height: 210,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(
                            width: 210,
                            height: 210,
                            child: Center(
                              child: Text(
                                'Failed to load QR code image.\nPlease check network.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_scanner, size: 18, color: Colors.grey[700]),
                          const SizedBox(width: 6),
                          Text(
                            'Scan with Gojek / Any QRIS App',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Supports Gojek, GoPay, OVO, DANA, ShopeePay, BCA, Livin, etc.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            ] else ...[
              const Center(child: CircularProgressIndicator()),
            ],

            const SizedBox(height: 24),

            // Deeplink Option (if on mobile or testing simulator)
            if (_currentPayment.deeplinkUrl != null) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppTheme.accentColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.open_in_new, size: 20, color: AppTheme.accentColor),
                label: const Text(
                  'Copy GoPay Deeplink / Simulator URL',
                  style: TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold),
                ),
                onPressed: _copyDeeplink,
              ),
              const SizedBox(height: 12),
            ],

            // Action: Check Status
            KosMateButton.primary(
              label: 'I Have Paid (Check Status)',
              icon: Icons.refresh_rounded,
              isLoading: _isCheckingStatus,
              onPressed: _checkStatus,
            ),
            const SizedBox(height: 10),

            // Cancel action
            TextButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.grey),
              label: Text(
                _isCancelling ? 'Cancelling...' : 'Cancel payment session',
                style: const TextStyle(color: Colors.grey),
              ),
              onPressed: _isCancelling ? null : _cancelPayment,
            ),
          ],
        ),
      ),
    );
  }
}

