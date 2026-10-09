import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/upload_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _uploadService = UploadService();
  bool _isUploading = false;
  String? _error;
  List<dynamic>? _dependencies;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['yaml', 'txt', 'json'],
      withData: true, // needed for web — gives us file.bytes
    );
    if (result == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
      _dependencies = null;
    });

    try {
      final response = await _uploadService.uploadDependencyFile(result.files.first);
      setState(() => _dependencies = response['dependencies']);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload dependency file')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: _isUploading ? null : _pickAndUpload,
              icon: const Icon(Icons.upload_file),
              label: Text(_isUploading ? 'Uploading...' : 'Pick pubspec.yaml / requirements.txt / package.json'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_dependencies != null) ...[
              const SizedBox(height: 24),
              Text('${_dependencies!.length} dependencies found', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _dependencies!.length,
                  itemBuilder: (context, i) {
                    final dep = _dependencies![i];
                    return ListTile(
                      title: Text(dep['name']),
                      subtitle: Text('${dep['ecosystem']} · ${dep['version']}'),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}