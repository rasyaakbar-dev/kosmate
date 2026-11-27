import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/payment_model.dart';

class QrisPaymentCard extends StatelessWidget {
  final PaymentModel payment;
  final VoidCallback onPayPressed;
  final VoidCallback onSubmitReceiptPressed;

  const QrisPaymentCard({
    super.key,
    required this.payment,
    required this.onPayPressed,
    required this.onSubmitReceiptPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasQrUrl =
        payment.qrCodeUrl != null && payment.qrCodeUrl!.trim().isNotEmpty;

    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderMedium, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                if (hasQrUrl)
                  Image.network(
                    payment.qrCodeUrl!.trim(),
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _buildFallbackQr(),
                  )
                else
                  _buildFallbackQr(),
                const SizedBox(height: 8),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 16,
                      color: AppTheme.textDark,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Scan with Gojek / Any QRIS App',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPayPressed,
                  icon: const Icon(Icons.payment_rounded, size: 18),
                  label: Text(
                    hasQrUrl
                        ? 'Pay / Simulate Payment'
                        : 'Pay via QRIS / E-Wallet',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text(
                'Submit bank transfer receipt',
                style: TextStyle(fontSize: 12),
              ),
              onPressed: onSubmitReceiptPressed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackQr() {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_rounded, size: 80, color: AppTheme.primaryColor),
          SizedBox(height: 6),
          Text(
            'QRIS Code Ready',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
