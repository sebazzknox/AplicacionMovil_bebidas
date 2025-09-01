import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Configuración Cloudinary (unsigned)
class CloudinaryService {
  /// TODO: poné tus valores
  static const String cloudName = 'dlk7onebj';
  static const String uploadPreset = 'mi_default'; // unsigned
  static const String apiBase =
      'https://api.cloudinary.com/v1_1';

  /// Sube bytes y devuelve secureUrl + publicId
  static Future<CloudinaryUploadResult> uploadBytes(
    Uint8List bytes, {
    String filename = 'promo.jpg',
    String folder = 'promos',
    String resourceType = 'image',
  }) async {
    final uri = Uri.parse('$apiBase/$cloudName/$resourceType/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return CloudinaryUploadResult(
        secureUrl: json['secure_url'] as String,
        publicId: json['public_id'] as String,
        resourceType: json['resource_type'] as String?,
        format: json['format'] as String?,
      );
    } else {
      throw Exception('Cloudinary error: ${res.statusCode} ${res.body}');
    }
  }
}

class CloudinaryUploadResult {
  final String secureUrl;
  final String publicId;
  final String? resourceType;
  final String? format;

  CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    this.resourceType,
    this.format,
  });
}