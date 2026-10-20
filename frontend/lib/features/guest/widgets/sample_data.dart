import 'dart:convert';
import 'dart:typed_data';

class SampleDependencyFile {
  const SampleDependencyFile({
    required this.name,
    required this.filename,
    required this.ecosystem,
    required this.description,
    required this.rawContent,
  });

  final String name;
  final String filename;
  final String ecosystem;
  final String description;
  final String rawContent;

  Uint8List get bytes => Uint8List.fromList(utf8.encode(rawContent));
}

class SampleDependencyFiles {
  static const flutterSample = SampleDependencyFile(
    name: 'Flutter Mobile App',
    filename: 'pubspec.yaml',
    ecosystem: 'pub (Dart/Flutter)',
    description: 'Real client stack with network, state & utilities',
    rawContent: '''name: mobile_client
description: Mobile client application
version: 1.2.0+14

environment:
  sdk: ^3.0.0

dependencies:
  flutter:
    sdk: flutter
  http: 1.2.0
  provider: 6.1.1
  shared_preferences: 2.2.2
  intl: 0.19.0
  path: 1.9.0
  url_launcher: 6.2.4
  crypto: 3.0.3
''',
  );

  static const pythonSample = SampleDependencyFile(
    name: 'Python Microservice',
    filename: 'requirements.txt',
    ecosystem: 'PyPI (Python)',
    description: 'Data service with API, serialization & utilities',
    rawContent: '''fastapi==0.110.0
pydantic==2.6.4
requests==2.31.0
urllib3==2.2.1
joblib==1.3.2
pandas==2.2.1
pytest==8.0.2
''',
  );

  static const nodeSample = SampleDependencyFile(
    name: 'Node.js Web Backend',
    filename: 'package.json',
    ecosystem: 'npm (JavaScript/TypeScript)',
    description: 'Express microservice with common utilities',
    rawContent: '''{
  "name": "api-gateway",
  "version": "2.4.0",
  "dependencies": {
    "express": "4.19.2",
    "lodash": "4.17.21",
    "axios": "1.6.8",
    "cors": "2.8.5",
    "dotenv": "16.4.5",
    "jsonwebtoken": "9.0.2"
  }
}
''',
  );

  static const List<SampleDependencyFile> all = [
    flutterSample,
    pythonSample,
    nodeSample,
  ];
}
