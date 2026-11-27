import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';

class StorageService {
  final SupabaseClient _client;
  static int _uploadCounter = 0;

  StorageService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

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
    String? mimeType,
  }) async {
    try {
      await _client.storage
          .from(bucketName)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: false, contentType: mimeType),
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

  String _uniqueFileName(String prefix, String extension) {
    _uploadCounter = (_uploadCounter + 1) % 100000;
    final micros = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${micros}_$_uploadCounter.$extension';
  }

  Future<String> uploadHouseImage(
    int? houseId,
    Uint8List bytes, {
    String extension = 'jpg',
  }) {
    final safeExtension = _imageExtension(extension);
    final prefix = houseId != null ? 'house_$houseId' : 'house_new';
    return uploadBytes(
      bucketName: SupabaseConstants.roomImagesBucket,
      path: _uniqueFileName(prefix, safeExtension),
      bytes: bytes,
      mimeType: _imageMimeType(safeExtension),
    );
  }

  Future<String> uploadRoomImage(
    int? roomId,
    Uint8List bytes, {
    String extension = 'jpg',
  }) {
    final safeExtension = _imageExtension(extension);
    final prefix = roomId != null ? 'room_$roomId' : 'room_new';
    return uploadBytes(
      bucketName: SupabaseConstants.roomImagesBucket,
      path: _uniqueFileName(prefix, safeExtension),
      bytes: bytes,
      mimeType: _imageMimeType(safeExtension),
    );
  }

  Future<String> uploadPaymentReceipt(
    int paymentId,
    Uint8List bytes,
    String extension,
  ) {
    final safeExtension = _imageExtension(extension);
    return uploadPrivateBytes(
      bucketName: SupabaseConstants.paymentReceiptsBucket,
      path: _uniqueFileName('payment_$paymentId', safeExtension),
      bytes: bytes,
      mimeType: _imageMimeType(safeExtension),
    );
  }

  Future<String> uploadComplaintAttachment(
    int userId,
    Uint8List bytes,
    String extension,
  ) {
    final safeExtension = _imageExtension(extension);
    return uploadPrivateBytes(
      bucketName: SupabaseConstants.complaintAttachmentsBucket,
      path: _uniqueFileName('complaint_$userId', safeExtension),
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
    final safeExtension = _imageExtension(extension);
    final fileName = _uniqueFileName('user_$userId', safeExtension);
    try {
      final url = await uploadBytes(
        bucketName: SupabaseConstants.avatarsBucket,
        path: fileName,
        bytes: bytes,
        mimeType: _imageMimeType(safeExtension),
      );
      return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
    } catch (_) {
      // Fallback to room-images bucket if avatars bucket is unavailable.
      try {
        final fallbackUrl = await uploadBytes(
          bucketName: SupabaseConstants.roomImagesBucket,
          path: 'avatars/$fileName',
          bytes: bytes,
          mimeType: _imageMimeType(safeExtension),
        );
        return '$fallbackUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      } catch (_) {
        rethrow;
      }
    }
  }

  Future<void> deleteAvatar(
    int userId, {
    String? avatarUrl,
    String extension = 'jpg',
  }) async {
    final storedImage = avatarUrl == null ? null : _avatarObject(avatarUrl);
    if (storedImage != null) {
      try {
        await _client.storage.from(storedImage.$1).remove([storedImage.$2]);
      } catch (e) {
        throw ServiceException('Failed to remove profile image.', cause: e);
      }
      return;
    }

    // Legacy non-timestamped path cleanup if avatarUrl is unavailable.
    try {
      await _client.storage.from(SupabaseConstants.avatarsBucket).remove([
        'user_$userId.$extension',
      ]);
      await _client.storage.from(SupabaseConstants.roomImagesBucket).remove([
        'avatars/user_$userId.$extension',
      ]);
    } catch (e) {
      throw ServiceException('Failed to remove profile image.', cause: e);
    }
  }

  (String, String)? _avatarObject(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.host != Uri.parse(SupabaseConstants.supabaseUrl).host) {
      return null;
    }

    final segments = uri.pathSegments;
    final objectIndex = segments.indexOf('object');
    if (objectIndex < 0 ||
        segments.length <= objectIndex + 3 ||
        segments[objectIndex + 1] != 'public') {
      return null;
    }

    final bucket = segments[objectIndex + 2];
    if (bucket != SupabaseConstants.avatarsBucket &&
        bucket != SupabaseConstants.roomImagesBucket) {
      return null;
    }
    return (bucket, segments.skip(objectIndex + 3).join('/'));
  }
}
