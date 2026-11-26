import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../models/user_model.dart';

class OwnerInformationCard extends StatelessWidget {
  final UserModel? owner;
  final bool compact;

  const OwnerInformationCard({
    super.key,
    required this.owner,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = owner?.name.trim();
    final phone = owner?.phone.trim();
    final email = owner?.email.trim();

    return Container(
      width: double.infinity,
      padding: compact ? EdgeInsets.zero : const EdgeInsets.all(14),
      decoration: compact
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            const Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: AppTheme.accentColor,
                ),
                SizedBox(width: 8),
                Text(
                  'Owner Information',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foregroundColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          _buildDetail(
            Icons.person_outline_rounded,
            name?.isNotEmpty == true ? name! : 'Owner information unavailable',
            emphasize: true,
          ),
          if (phone?.isNotEmpty == true)
            _buildDetail(Icons.phone_outlined, phone!),
          if (email?.isNotEmpty == true)
            _buildDetail(Icons.email_outlined, email!),
        ],
      ),
    );
  }

  Widget _buildDetail(IconData icon, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
                color: emphasize
                    ? AppTheme.foregroundColor
                    : AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
