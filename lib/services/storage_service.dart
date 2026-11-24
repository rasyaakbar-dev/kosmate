import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';

class StorageService {
  final SupabaseClient _client = supabase;

  Future<String> uploadBytes({
    required String bucketName,
    required String path,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    await _uploadBytes(
      bucketName: bucketName,
      path: path,
      bytes: bytes,
      mimeType: mimeType,
      upsert: true,
    );
    return _client.storage.from(bucketName).getPublicUrl(path);
  }

  Future<String> uploadPrivateBytes({
    required String bucketName,
    required String path,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    await _uploadBytes(
      bucketName: bucketName,
      path: path,
      bytes: bytes,
      mimeType: mimeType,
      upsert: false,
    );
    return path;
  }

  Future<String> createSignedUrl({
    required String bucketName,
    required String path,
    Duration expiresIn = const Duration(minutes: 30),
  }) async {
    final objectPath = _objectPath(bucketName, path);

    try {
      return await _client.storage
          .from(bucketName)
          .createSignedUrl(objectPath, expiresIn.inSeconds);
    } catch (e) {
      throw ServiceException('Failed to create a private file link.', cause: e);
    }
  }

  Future<void> _uploadBytes({
    required String bucketName,
    required String path,
    required Uint8List bytes,
    required bool upsert,
    String? mimeType,
  }) async {
    try {
      await _client.storage
          .from(bucketName)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: upsert, contentType: mimeType),
          );
    } catch (e) {
      throw ServiceException('Failed to upload file to storage.', cause: e);
    }
  }

  String _objectPath(String bucketName, String path) {
    final uri = Uri.tryParse(path);
    if (uri == null) {
      throw const ServiceException('Invalid private file path.');
    }
    if (!uri.hasScheme) {
      if (path.startsWith('/') || path.split('/').contains('..')) {
        throw const ServiceException('Invalid private file path.');
      }
      return path;
    }

    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(bucketName);
    if (uri.scheme != 'https' ||
        uri.host != Uri.parse(SupabaseConstants.supabaseUrl).host ||
        bucketIndex < 1 ||
        segments[bucketIndex - 1] != 'public' ||
        bucketIndex == segments.length - 1) {
      throw const ServiceException(
        'The file URL does not belong to this private storage bucket.',
      );
    }
    return segments.skip(bucketIndex + 1).join('/');
  }

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

  Future<String> uploadPaymentReceipt(
    int paymentId,
    Uint8List bytes,
    String extension,
  ) async {
    final safeExtension = _imageExtension(extension);
    final fileName =
        'payment_${paymentId}_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
    return uploadPrivateBytes(
      bucketName: SupabaseConstants.paymentReceiptsBucket,
      path: fileName,
      bytes: bytes,
      mimeType: _imageMimeType(safeExtension),
    );
  }

  Future<String> uploadComplaintAttachment(
    int userId,
    Uint8List bytes,
    String extension,
  ) async {
    final safeExtension = _imageExtension(extension);
    final fileName =
        'complaint_${userId}_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
    return uploadPrivateBytes(
      bucketName: SupabaseConstants.complaintAttachmentsBucket,
      path: fileName,
      bytes: bytes,
      mimeType: _imageMimeType(safeExtension),
    );
  }

  String _imageExtension(String extension) {
    final normalized = extension.toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(normalized)
        ? normalized
        : 'jpg';
  }

  String _imageMimeType(String extension) =>
      extension == 'jpg' || extension == 'jpeg'
      ? 'image/jpeg'
      : 'image/$extension';

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
