import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';

class StorageService {
  final SupabaseClient _client = supabase;

  /// Upload file bytes to a target bucket and return public URL
  Future<String> uploadBytes({
    required String bucketName,
    required String path,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    await _client.storage.from(bucketName).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: mimeType,
      ),
    );

    return _client.storage.from(bucketName).getPublicUrl(path);
  }

  /// Upload room image
  Future<String> uploadRoomImage(int roomId, Uint8List bytes, String extension) async {
    final fileName = 'room_${roomId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    return await uploadBytes(
      bucketName: SupabaseConstants.roomImagesBucket,
      path: fileName,
      bytes: bytes,
    );
  }

  /// Upload payment receipt proof
  Future<String> uploadPaymentReceipt(int paymentId, Uint8List bytes, String extension) async {
    final fileName = 'payment_${paymentId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    return await uploadBytes(
      bucketName: SupabaseConstants.paymentReceiptsBucket,
      path: fileName,
      bytes: bytes,
    );
  }

  /// Upload complaint attachment
  Future<String> uploadComplaintAttachment(int userId, Uint8List bytes, String extension) async {
    final fileName = 'complaint_${userId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    return await uploadBytes(
      bucketName: SupabaseConstants.complaintAttachmentsBucket,
      path: fileName,
      bytes: bytes,
    );
  }
}

