import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// BR-10: Nén ảnh phía client xuống dưới 500KB trước khi upload Cloudinary.
class ImageUtil {
  ImageUtil._();

  static const int maxSizeBytes = 500 * 1024; // 500KB

  /// Nén ảnh tại [filePath], giảm dần quality cho tới khi < 500KB.
  /// Trả về null nếu nén thất bại.
  static Future<Uint8List?> compressUnder500Kb(String filePath) async {
    for (final quality in [80, 60, 40, 25, 10]) {
      final result = await FlutterImageCompress.compressWithFile(
        filePath,
        quality: quality,
        minWidth: 1080,
        minHeight: 1080,
      );
      if (result == null) return null;
      if (result.lengthInBytes <= maxSizeBytes) return result;
    }
    return null;
  }
}
