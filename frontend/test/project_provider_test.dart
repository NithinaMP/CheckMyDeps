import 'dart:async';

// import 'package:checkmydeps/core/services/api_client.dart';
// import 'package:checkmydeps/features/projects/models/project.dart';
// import 'package:checkmydeps/features/projects/providers/project_provider.dart';
// import 'package:checkmydeps/features/projects/services/project_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/api_client.dart';
import 'package:frontend/features/projects/models/project.dart';
import 'package:frontend/features/projects/providers/project_provider.dart';
import 'package:frontend/features/projects/services/project_service.dart';

Project proj(String id, String org, {String name = 'App'}) => Project(
  id: id,
  orgId: org,
  name: name,
  ecosystem: ProjectEcosystem.pub,
);

class FakeProjectService extends ProjectService {
  FakeProjectService() : super(ApiClient());

  final Map<String, List<Project>> byOrg = {};
  ApiException? listError;
  ApiException? createError;
  Future<List<Project>> Function(String orgId)? listOverride;

  @override
  Future<List<Project>> list(String orgId) async {
    if (listOverride != null) return listOverride!(orgId);
    if (listError != null) throw listError!;
    return byOrg[orgId] ?? [];
  }

  @override
  Future<Project> create(
      String orgId, {
        required String name,
        required ProjectEcosystem ecosystem,
        String? repoUrl,
      }) async {
    if (createError != null) throw createError!;
    return Project(
      id: 'new-$name',
      orgId: orgId,
      name: name,
      ecosystem: ecosystem,
      repoUrl: repoUrl,
    );
  }
}

void main() {
  group('Project model', () {
    test('parses a valid payload', () {
      final p = Project.fromJson({
        'id': 'p1',
        'org_id': 'o1',
        'name': 'App',
        'ecosystem': 'PyPI',
        'repo_url': 'https://github.com/a/b',
        'created_at': '2026-10-20T10:00:00Z',
      });
      expect(p.ecosystem, ProjectEcosystem.pypi);
      expect(p.repoUrl, 'https://github.com/a/b');
      expect(p.createdAt, isNotNull);
    });

    test('rejects unknown ecosystem or missing fields', () {
      expect(
            () => Project.fromJson(
            {'id': 'p', 'org_id': 'o', 'name': 'A', 'ecosystem': 'cargo'}),
        throwsFormatException,
      );
      expect(() => Project.fromJson({'name': 'A', 'ecosystem': 'pub'}),
          throwsFormatException);
    });
  });

  group('ProjectProvider', () {
    late FakeProjectService service;
    late ProjectProvider provider;

    setUp(() {
      service = FakeProjectService()
        ..byOrg['a'] = [proj('pa', 'a')]
        ..byOrg['b'] = [proj('pb', 'b')];
      provider = ProjectProvider(service);
    });

    test('loads projects for an organisation', () async {
      await provider.load('a');
      expect(provider.status, ProjectLoadStatus.ready);
      expect(provider.orgId, 'a');
      expect(provider.projects.single.id, 'pa');
    });

    test('switching organisation never shows the previous list', () async {
      await provider.load('a');
      final pending = provider.load('b');
      expect(provider.orgId, 'b');
      expect(provider.projects, isEmpty); // cleared immediately
      await pending;
      expect(provider.projects.single.id, 'pb');
    });

    test('a slow earlier load cannot overwrite a newer one', () async {
      final slow = Completer<List<Project>>();
      final fast = Completer<List<Project>>();
      service.listOverride = (org) => org == 'a' ? slow.future : fast.future;

      final first = provider.load('a');
      final second = provider.load('b');
      fast.complete([proj('pb', 'b')]);
      await second;
      slow.complete([proj('pa', 'a')]);
      await first;

      expect(provider.orgId, 'b');
      expect(provider.projects.single.id, 'pb');
    });

    test('load error is exposed', () async {
      service.listError = const ApiException(ApiErrorKind.network, 'down');
      await provider.load('a');
      expect(provider.status, ProjectLoadStatus.error);
      expect(provider.loadError?.message, 'down');
    });

    test('create inserts the project first for the open organisation', () async {
      await provider.load('a');
      final ok = await provider.createProject(
        orgId: 'a',
        name: 'New',
        ecosystem: ProjectEcosystem.npm,
      );
      expect(ok, isTrue);
      expect(provider.projects.first.name, 'New');
      expect(provider.projects, hasLength(2));
      expect(provider.isBusy, isFalse);
    });

    test('create failure (e.g. developer role) keeps the list and exposes error',
            () async {
          await provider.load('a');
          service.createError = const ApiException(
              ApiErrorKind.forbidden, 'needs lead',
              statusCode: 403);
          final ok = await provider.createProject(
            orgId: 'a',
            name: 'Nope',
            ecosystem: ProjectEcosystem.pub,
          );
          expect(ok, isFalse);
          expect(provider.actionError?.message, 'needs lead');
          expect(provider.projects, hasLength(1));
          expect(provider.isBusy, isFalse);
        });

    test('reset clears everything', () async {
      await provider.load('a');
      provider.reset();
      expect(provider.orgId, isNull);
      expect(provider.projects, isEmpty);
      expect(provider.status, ProjectLoadStatus.idle);
    });
  });
}