import 'dart:typed_data';

import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Sube imágenes al bucket Supabase `category-images` (ver migración 016).
class CategoryImageService {
  static const _bucket = 'category-images';
  static const _uuid = Uuid();

  static bool get canUpload => SupabaseService.isInitialized;

  /// Sube bytes y devuelve la URL pública, o null si falla / no hay Supabase.
  static Future<String?> uploadCategoryImage({
    required int categoryId,
    required Uint8List bytes,
    String mimeType = 'image/jpeg',
  }) async {
    if (!canUpload || bytes.isEmpty) return null;
    try {
      final ext = _extensionForMime(mimeType);
      final path = 'categories/$categoryId/${_uuid.v4()}.$ext';
      final client = SupabaseService.instance.client;
      await client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: false,
            ),
          );
      return client.storage.from(_bucket).getPublicUrl(path);
    } catch (e, st) {
      // ignore: avoid_print
      print('CategoryImageService.uploadCategoryImage: $e\n$st');
      return null;
    }
  }

  static String _extensionForMime(String mime) {
    final m = mime.toLowerCase();
    if (m.contains('png')) return 'png';
    if (m.contains('webp')) return 'webp';
    return 'jpg';
  }
}

