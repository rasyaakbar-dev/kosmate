import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TermsOfServiceDialog extends StatelessWidget {
  const TermsOfServiceDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const TermsOfServiceDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gavel_rounded, color: AppTheme.accentColor, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Terms of Service',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.foregroundColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Last updated: November 2026',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),

              // Scrollable Terms Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('1. Acceptance of Terms'),
                      _buildSectionBody(
                        'By creating an account and using KosMate, you agree to comply with and be bound by these Terms of Service. If you do not agree with any part of these terms, you must not use the application.',
                      ),
                      const SizedBox(height: 16),

                      _buildSectionTitle('2. User Accounts & Verification'),
                      _buildSectionBody(
                        '• Users must provide accurate, current, and complete registration information including legal name, valid phone number, and email address.\n'
                        '• You are responsible for safeguarding your login credentials and for any activity under your account.\n'
                        '• Kos owners must have verified rights to manage and rent the listed boarding houses.',
                      ),
                      const SizedBox(height: 16),

                      _buildSectionTitle('3. Bookings & Occupancy'),
                      _buildSectionBody(
                        '• Room booking requests are subject to confirmation and approval by the boarding house owner.\n'
                        '• An approved booking constitutes a binding lease agreement for the selected duration.\n'
                        '• Room occupancy status is automatically updated upon approval of the booking request.',
                      ),
                      const SizedBox(height: 16),

                      _buildSectionTitle('4. Payments & Billing'),
                      _buildSectionBody(
                        '• Payments are processed securely via integrated payment gateways (including Midtrans Core API and supported e-wallets).\n'
                        '• Renters must settle invoices on or before the specified due date.\n'
                        '• Late payments or unpaid invoices may result in penalty charges or termination of the rental agreement according to house rules.',
                      ),
                      const SizedBox(height: 16),

                      _buildSectionTitle('5. House Rules & Maintenance Complaints'),
                      _buildSectionBody(
                        '• Renters agree to respect the designated boarding house rules, curfews, and common area regulations.\n'
                        '• Maintenance issues or disputes should be submitted promptly via the KosMate Complaint system.\n'
                        '• Kos owners are required to review and respond to tenant complaints within a reasonable timeframe.',
                      ),
                      const SizedBox(height: 16),

                      _buildSectionTitle('6. Privacy & Data Protection'),
                      _buildSectionBody(
                        'Your privacy is critically important to us. Personal data and uploaded documents are encrypted and managed strictly in accordance with modern security standards and PostgreSQL Row-Level Security policies.',
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'I Agree & Accept',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w700,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.foregroundColor,
      ),
    );
  }

  Widget _buildSectionBody(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          height: 1.5,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}

