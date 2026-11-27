import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kosmate_components.dart';

void showChangePasswordDialog(BuildContext context) {
  final newPassCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool obscureNew = true;
  bool obscureConfirm = true;
  bool isSaving = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: AppTheme.accentColor),
            SizedBox(width: 10),
            Text(
              'Change Password',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: newPassCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(
                    Icons.vpn_key_outlined,
                    color: AppTheme.textMuted,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter new password';
                  }
                  if (val.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPassCtrl,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(
                    Icons.lock_clock_outlined,
                    color: AppTheme.textMuted,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setDialogState(
                      () => obscureConfirm = !obscureConfirm,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (val != newPassCtrl.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          KosMateCancelButton(
            isOutlined: false,
            onPressed: isSaving ? null : () => Navigator.pop(ctx),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: isSaving
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(ctx);
                    setDialogState(() => isSaving = true);
                    try {
                      await sl.auth.updatePassword(newPassCtrl.text.trim());
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Password changed successfully!'),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Failed to update password: $e'),
                          backgroundColor: AppTheme.destructiveColor,
                        ),
                      );
                    }
                  },
            icon: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_reset, size: 18),
            label: const Text('Update Password'),
          ),
        ],
      ),
    ),
  ).whenComplete(() {
    newPassCtrl.dispose();
    confirmPassCtrl.dispose();
  });
}

void showDeleteAccountDialog(
  BuildContext context, {
  required Future<void> Function() onConfirmed,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.destructiveColor),
          SizedBox(width: 10),
          Text(
            'Delete Account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.destructiveColor,
            ),
          ),
        ],
      ),
      content: const Text(
        'Are you sure you want to permanently delete your account?\n\nThis action cannot be undone. All your profile data, personal history, and active sessions will be removed.',
        style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.destructiveColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            Navigator.pop(ctx);
            await onConfirmed();
          },
          icon: const Icon(Icons.delete_forever_outlined, size: 18),
          label: const Text('Delete Permanently'),
        ),
      ],
    ),
  );
}
