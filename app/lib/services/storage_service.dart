import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudinaryConfig {
  static const String cloudName = 'kajew0fe';
  static const String uploadPreset = 'surplusbite';
  static const String uploadUrl =
      'https://api.cloudinary.com/v1_1/kajew0fe/image/upload';
}

class StorageService {
  Future<String> uploadImage(File file, String path) async {
    final request = http.MultipartRequest('POST', Uri.parse(CloudinaryConfig.uploadUrl));

    request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
    request.fields['folder'] = 'surplusbite/$path';
    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode} $responseBody');
    }

    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  Future<List<String>> uploadImages(List<File> files, String path) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadImage(file, path);
      urls.add(url);
    }
    return urls;
  }

  Future<void> deleteImage(String url) async {
    // Delete requires a signed API call (server-side), skip for free tier.
    // Alternatively leave images in Cloudinary - free tier gives 25GB.
    // Images without a listing can be periodically cleaned via Cloudinary UI.
  }

  Future<void> deleteImages(List<String> urls) async {
    for (final url in urls) {
      await deleteImage(url);
    }
  }
}
