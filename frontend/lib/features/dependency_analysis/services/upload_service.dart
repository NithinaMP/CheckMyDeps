import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../authentication/services/auth_service.dart';

class UploadService {
  static const String baseUrl = 'http://127.0.0.1:8000'; // change when backend is deployed

  Future<Map<String, dynamic>> uploadDependencyFile(PlatformFile file) async {
    final token = await AuthService().getIdToken();
    print('TOKEN: $token');
    final uri = Uri.parse('$baseUrl/dependency/upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Upload failed');
    }
    return jsonDecode(response.body);
  }
}