import 'dart:typed_data';

// import 'package:checkmydeps/core/services/api_client.dart';
// import 'package:checkmydeps/features/projects/models/project.dart';
// import 'package:checkmydeps/features/projects/models/project_analysis.dart';
// import 'package:checkmydeps/features/projects/providers/project_analysis_provider.dart';
// import 'package:checkmydeps/features/projects/services/project_analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/api_client.dart';
import 'package:frontend/features/projects/models/project.dart';
import 'package:frontend/features/projects/models/project_analysis.dart';
import 'package:frontend/features/projects/providers/project_analysis_provider.dart';
import 'package:frontend/features/projects/services/project_analysis_service.dart';

Map<String, dynamic> summaryJson({int total = 4}) => {
  'compliance_score': 72,
  'highest_risk': 'HIGH',
  'total_dependencies': total,
  'analyzed': total,
  'failed': 0,
  'risk_distribution': {'LOW': 1, 'MEDIUM': 1, 'HIGH': 2, 'CRITICAL': 0},
  'maintained': 3,
  'unmaintained': 1,
  'maintenance_undetermined': 0,
  'vulnerable': 1,
  'license_violations': 1,
  'needs_review': 2,
};

Map<String, dynamic> storedJson(String id, {String filename = 'requirements.txt'}) => {
  'id': id,
  'project_id': 'p1',
  'filename': filename,
  'created_at': '2026-10-21T10:00:00Z',
  'created_by_email': 'a@x.io',
  'summary': summaryJson(),
  'dependencies': <dynamic>[],
};

AnalysisHistoryItem historyItem(String id) => AnalysisHistoryItem.fromJson({
  'id': id,
  'filename': 'requirements.txt',
  'created_at': '2026-10-21T10:00:00Z',
  'created_by_email': 'a@x.io',
  'summary': summaryJson(),
});

class FakeAnalysisService extends ProjectAnalysisService {
  FakeAnalysisService() : super(ApiClient());

  List<AnalysisHistoryItem> historyResult = [];
  ApiException? historyError;
  ApiException? runError;
  String? lastRunFilename;

  @override
  Future<List<AnalysisHistoryItem>> history(String orgId, String projectId) async {
    if (historyError != null) throw historyError!;
    return historyResult;
  }

  @override
  Future<StoredAnalysis> get(String orgId, String projectId, String analysisId) async =>
      StoredAnalysis.fromJson(storedJson(analysisId));

  @override
  Future<StoredAnalysis> run(String orgId, String projectId,
      {required String filename, required Uint8List bytes}) async {
    lastRunFilename = filename;
    if (runError != null) throw runError!;
    return StoredAnalysis.fromJson(storedJson('new-run', filename: filename));
  }
}

Uint8List bytesOf(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  group('models', () {
    test('StoredAnalysis parses id, metadata and the shared result model', () {
      final a = StoredAnalysis.fromJson(storedJson('a1'));
      expect(a.id, 'a1');
      expect(a.createdByEmail, 'a@x.io');
      expect(a.createdAt, isNotNull);
      expect(a.result.summary.complianceScore, 72);
      expect(a.result.summary.vulnerable, 1);
    });

    test('invalid payloads are rejected', () {
      expect(() => StoredAnalysis.fromJson({'summary': {}, 'dependencies': []}),
          throwsFormatException);
      expect(() => AnalysisHistoryItem.fromJson({'id': 'x', 'filename': 'f'}),
          throwsFormatException);
    });

    test('ecosystem file matching', () {
      expect(ProjectEcosystem.pub.acceptsFile('pubspec.yaml'), isTrue);
      expect(ProjectEcosystem.pub.acceptsFile('requirements.txt'), isFalse);
      expect(ProjectEcosystem.pypi.acceptsFile('Requirements.TXT'), isTrue);
      expect(ProjectEcosystem.npm.acceptsFile('package.json'), isTrue);
      expect(ProjectEcosystem.npm.acceptsFile('pubspec.yaml'), isFalse);
    });

    test('Project parses latest_analysis; a malformed pointer does not break it', () {
      final ok = Project.fromJson({
        'id': 'p1', 'org_id': 'o1', 'name': 'App', 'ecosystem': 'pub',
        'latest_analysis': {
          'id': 'a1', 'filename': 'pubspec.yaml',
          'created_at': '2026-10-21T10:00:00Z', 'summary': summaryJson(),
        },
      });
      expect(ok.latestAnalysis?.summary.complianceScore, 72);

      final bad = Project.fromJson({
        'id': 'p1', 'org_id': 'o1', 'name': 'App', 'ecosystem': 'pub',
        'latest_analysis': {'id': 5},
      });
      expect(bad.latestAnalysis, isNull);

      final none = Project.fromJson(
          {'id': 'p1', 'org_id': 'o1', 'name': 'App', 'ecosystem': 'pub'});
      expect(none.latestAnalysis, isNull);
    });
  });

  group('ProjectAnalysisProvider', () {
    late FakeAnalysisService service;
    late ProjectAnalysisProvider provider;

    setUp(() {
      service = FakeAnalysisService();
      provider = ProjectAnalysisProvider(service);
    });

    test('open loads history and shows the newest analysis', () async {
      service.historyResult = [historyItem('a2'), historyItem('a1')];
      await provider.open('o1', 'p1');
      expect(provider.history.map((h) => h.id), ['a2', 'a1']);
      expect(provider.selected?.id, 'a2');
      expect(provider.historyLoading, isFalse);
    });

    test('open with no history selects nothing', () async {
      await provider.open('o1', 'p1');
      expect(provider.history, isEmpty);
      expect(provider.selected, isNull);
    });

    test('history error is exposed', () async {
      service.historyError = const ApiException(ApiErrorKind.network, 'down');
      await provider.open('o1', 'p1');
      expect(provider.historyError?.message, 'down');
    });

    test('file validation', () async {
      await provider.open('o1', 'p1');
      provider.selectFile('notes.docx', bytesOf('x'), ProjectEcosystem.pypi);
      expect(provider.hasFile, isFalse);
      expect(provider.fileError, contains('not supported'));

      provider.selectFile('pubspec.yaml', bytesOf('x'), ProjectEcosystem.pypi);
      expect(provider.hasFile, isFalse);
      expect(provider.fileError, contains('requirements.txt'));

      provider.selectFile('requirements.txt', Uint8List(0), ProjectEcosystem.pypi);
      expect(provider.fileError, contains('empty'));

      provider.selectFile('requirements.txt',
          Uint8List(ProjectAnalysisProvider.maxFileBytes + 1), ProjectEcosystem.pypi);
      expect(provider.fileError, contains('too large'));

      provider.selectFile('requirements.txt', bytesOf('a==1'), ProjectEcosystem.pypi);
      expect(provider.hasFile, isTrue);
      expect(provider.fileError, isNull);
    });

    test('run without a file does nothing', () async {
      await provider.open('o1', 'p1');
      expect(await provider.run(), isFalse);
      expect(service.lastRunFilename, isNull);
    });

    test('successful run selects the result, prepends history, clears the file',
            () async {
          service.historyResult = [historyItem('a1')];
          await provider.open('o1', 'p1');
          provider.selectFile('requirements.txt', bytesOf('a==1'), ProjectEcosystem.pypi);

          expect(await provider.run(), isTrue);
          expect(service.lastRunFilename, 'requirements.txt');
          expect(provider.selected?.id, 'new-run');
          expect(provider.history.first.id, 'new-run');
          expect(provider.history, hasLength(2));
          expect(provider.hasFile, isFalse);
          expect(provider.isRunning, isFalse);
        });

    test('failed run keeps the file and exposes the backend message', () async {
      await provider.open('o1', 'p1');
      provider.selectFile('requirements.txt', bytesOf('a==1'), ProjectEcosystem.pypi);
      service.runError = const ApiException(
          ApiErrorKind.invalidRequest, 'wrong ecosystem',
          statusCode: 400);

      expect(await provider.run(), isFalse);
      expect(provider.runError?.message, 'wrong ecosystem');
      expect(provider.hasFile, isTrue);
      expect(provider.history, isEmpty);
      expect(provider.isRunning, isFalse);
    });

    test('opening another project clears the previous project state', () async {
      service.historyResult = [historyItem('a1')];
      await provider.open('o1', 'p1');
      provider.selectFile('requirements.txt', bytesOf('a==1'), ProjectEcosystem.pypi);

      service.historyResult = [];
      await provider.open('o1', 'p2');
      expect(provider.projectId, 'p2');
      expect(provider.history, isEmpty);
      expect(provider.selected, isNull);
      expect(provider.hasFile, isFalse);
    });

    test('reset clears everything', () async {
      service.historyResult = [historyItem('a1')];
      await provider.open('o1', 'p1');
      provider.reset();
      expect(provider.projectId, isNull);
      expect(provider.history, isEmpty);
      expect(provider.selected, isNull);
    });
  });
}