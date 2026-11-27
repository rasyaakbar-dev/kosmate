import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/kosmate_components.dart';
import '../../../../core/widgets/zoomable_image.dart';
import '../../../../models/payment_model.dart';

void showSubmitReceiptDialog(
  BuildContext context, {
  required PaymentModel payment,
  required VoidCallback onSubmitted,
}) {
  final messenger = ScaffoldMessenger.of(context);
  Uint8List? selectedImageBytes;
  String? selectedImageExt;
  bool isSubmitting = false;

  showDialog(
    context: context,
    barrierDismissible: !isSubmitting,
    builder: (ctx) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        Future<void> pickImage(ImageSource source) async {
          try {
            final picker = ImagePicker();
            final picked = await picker.pickImage(
              source: source,
              maxWidth: 1600,
              maxHeight: 1600,
              imageQuality: 85,
            );
            if (picked != null) {
              final bytes = await picked.readAsBytes();
              final ext = picked.name.split('.').last.toLowerCase();
              setDialogState(() {
                selectedImageBytes = bytes;
                selectedImageExt = ext.isNotEmpty ? ext : 'jpg';
              });
            }
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Failed to pick image: $e')),
              );
            }
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Submit Payment Receipt',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice: ${Formatters.formatCurrency(payment.amount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                if (selectedImageBytes != null) ...[
                  Stack(
                    children: [
                      ZoomableImage(
                        imageProvider: MemoryImage(selectedImageBytes!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            selectedImageBytes!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedImageBytes = null;
                              selectedImageExt = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.destructiveColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('Camera'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentColor,
                            side: const BorderSide(color: AppTheme.accentColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickImage(ImageSource.gallery),
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 18,
                          ),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentColor,
                            side: const BorderSide(color: AppTheme.accentColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          actions: [
            KosMateCancelButton(
              isOutlined: false,
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (selectedImageBytes == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please attach a receipt image.'),
                            backgroundColor: AppTheme.warningColor,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        final receiptPath = await sl.storage
                            .uploadPaymentReceipt(
                              payment.paymentId,
                              selectedImageBytes!,
                              selectedImageExt ?? 'jpg',
                            );

                        await sl.payment.submitReceipt(
                          paymentId: payment.paymentId,
                          receiptPath: receiptPath,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        onSubmitted();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Receipt submitted successfully!'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file, size: 18),
              label: const Text('Submit'),
            ),
          ],
        );
      },
    ),
  );
}
