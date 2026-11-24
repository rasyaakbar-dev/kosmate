import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';

class StorageService {
  final SupabaseClient _client = supabase;

  /// Upload file bytes to a target bucket and return public URL
  Future<String> uploadBytes({
    required String bucketName,
    required String path,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    try {
      await _client.storage
          .from(bucketName)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: mimeType),
          );

      return _client.storage.from(bucketName).getPublicUrl(path);
    } catch (e) {
      throw ServiceException('Failed to upload file to storage.', cause: e);
    }
  }

  /// Upload house image
  Future<String> uploadHouseImage(
    int? houseId,
    Uint8List bytes, {
    String extension = 'jpg',
  }) async {
    final prefix = houseId != null ? 'house_$houseId' : 'house_new';
    final fileName =
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    return await uploadBytes(
      bucketName: SupabaseConstants.roomImagesBucket,
      path: fileName,
      bytes: bytes,
      mimeType: 'image/jpeg',
    );
  }

  /// Upload room image
  Future<String> uploadRoomImage(
    int? roomId,
    Uint8List bytes, {
    String extension = 'jpg',
  }) async {
    final prefix = roomId != null ? 'room_$roomId' : 'room_new';
    final fileName =
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    return await uploadBytes(
      bucketName: SupabaseConstants.roomImagesBucket,
      path: fileName,
      bytes: bytes,
      mimeType: 'image/jpeg',
    );
  }

  /// Upload payment receipt proof
  Future<String> uploadPaymentReceipt(
    int paymentId,
    Uint8List bytes,
    String extension,
  ) async {
    final fileName =
        'payment_${paymentId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    return await uploadBytes(
      bucketName: SupabaseConstants.paymentReceiptsBucket,
      path: fileName,
      bytes: bytes,
    );
  }

  /// Upload complaint attachment
  Future<String> uploadComplaintAttachment(
    int userId,
    Uint8List bytes,
    String extension,
  ) async {
    final fileName =
        'complaint_${userId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    return await uploadBytes(
      bucketName: SupabaseConstants.complaintAttachmentsBucket,
      path: fileName,
      bytes: bytes,
    );
  }

  /// Upload user profile picture (efficient overwrite per user)
  Future<String> uploadAvatar(
    int userId,
    Uint8List bytes, {
    String extension = 'jpg',
  }) async {
    final fileName = 'user_$userId.$extension';
    try {
      final url = await uploadBytes(
        bucketName: SupabaseConstants.avatarsBucket,
        path: fileName,
        bytes: bytes,
        mimeType: 'image/jpeg',
      );
      return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      // If avatars bucket fails (e.g., not configured), try room-images fallback
      try {
        final fallbackUrl = await uploadBytes(
          bucketName: SupabaseConstants.roomImagesBucket,
          path: 'avatars/$fileName',
          bytes: bytes,
          mimeType: 'image/jpeg',
        );
        return '$fallbackUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      } catch (_) {
        // Re-throw original exception so user gets the accurate bucket error
        rethrow;
      }
    }
  }

  /// Delete user profile picture from storage
  Future<void> deleteAvatar(int userId, {String extension = 'jpg'}) async {
    final fileName = 'user_$userId.$extension';
    try {
      await _client.storage.from(SupabaseConstants.avatarsBucket).remove([
        fileName,
      ]);
    } catch (_) {}
    try {
      await _client.storage.from(SupabaseConstants.roomImagesBucket).remove([
        'avatars/$fileName',
      ]);
    } catch (_) {}
  }
}
