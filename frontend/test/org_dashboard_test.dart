import 'dart:async';
import 'dart:core';
// import 'dart:core';


// import 'package:checkmydeps/core/services/api_client.dart';
// import 'package:checkmydeps/features/organization/models/org_dashboard.dart';
// import 'package:checkmydeps/features/organization/providers/org_dashboard_provider.dart';
// import 'package:checkmydeps/fe/atures/organization/services/org_dashboard_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/api_client.dart';
import 'package:frontend/features/organization/models/org_dashboard.dart';
import 'package:frontend/features/organization/providers/org_dashboard_provider.dart';
import 'package:frontend/features/organization/services/org_dashboard_service.dart';

Map<String, dynamic> projectJson(String id, {bool analysed = true}) => {
  'id': id,
  'name': 'Proj $id',
  'ecosystem': 'PyPI',
  'repo_url': null,
  'created_at': '2026-10-01T10:00:00Z',
  if (analysed) ...{
    'analysis_id': 'a-$id',
    'filename': 'requirements.txt',
    'analysed_at': '2026-10-21T10:00:00Z',
    'compliance_score': 61,
    'highest_risk': 'HIGH',
    'risk_distribution': {'LOW': 1, 'MEDIUM': 0, 'HIGH': 2, 'CRITICAL': 0},
    'total_dependencies': 3,
    'analyzed': 3,
    'failed': 0,
    'vulnerable': 1,
    'license_violations': 1,
    'unmaintained': 2,
  },
};

Map<String, dynamic> dashboardJson({List<Object?>? attention}) => {
  'generated_at': '2026-10-21T12:00:00Z',
  'totals': {
    'projects': 3,
    'analysed_projects': 2,
    'not_analysed_projects': 1,
    'dependencies_total': 7,
    'dependencies_analysed': 6,
    'dependencies_failed': 1,
    'vulnerable': 2,
    'license_violations': 1,
    'unmaintained': 3,
    'maintenance_undetermined': 1,
    'needs_review': 2,
    'risk_distribution': {'LOW': 2, 'MEDIUM': 1, 'HIGH': 3, 'CRITICAL': 0},
    'projects_by_highest_risk': {'LOW': 0, 'MEDIUM': 0, 'HIGH': 2, 'CRITICAL': 0},
    'compliance_score': 57,
    'compliance_projects': 2,
  },
  'recent_analyses': [projectJson('p1')],
  'attention_projects': attention ?? [projectJson('p1'), projectJson('p2')],
  'not_analysed_projects': [projectJson('p3', analysed: false)],
};

class FakeDashboardService extends OrgDashboardService {
  FakeDashboardService() : super(ApiClient());

  OrgDashboard? result;
  ApiException? error;
  Future<OrgDashboard> Function(String orgId)? loadOverride;

  @override
  Future<OrgDashboard> load(String orgId) async {
    if (loadOverride != null) return loadOverride!(orgId);
    if (error != null) throw error!;
    return result!;
  }
}

void main() {
  group('OrgDashboard model', () {
    test('parses totals and project lists', () {
      final d = OrgDashboard.fromJson(dashboardJson());
      expect(d.totals.projects, 3);
      expect(d.totals.complianceScore, 57);
      expect(d.totals.riskDistribution['HIGH'], 3);
      expect(d.attentionProjects, hasLength(2));
      expect(d.recentAnalyses.single.filename, 'requirements.txt');
      expect(d.notAnalysedProjects.single.hasAnalysis, isFalse);
      expect(d.generatedAt, isNotNull);
    });

    test('toProject carries what the detail screen needs', () {
      final p = OrgDashboard.fromJson(dashboardJson())
          .attentionProjects
          .first
          .toProject('org-1');
      expect(p.orgId, 'org-1');
      expect(p.id, 'p1');
      expect(p.ecosystem.apiValue, 'PyPI');
    });

    test('malformed project entries are skipped, not fatal', () {
      final d = OrgDashboard.fromJson(dashboardJson(attention: [
        {'id': 5},
        'junk',
        {'id': 'x', 'name': 'X', 'ecosystem': 'cargo'},
        projectJson('good'),
      ]));
      expect(d.attentionProjects.single.id, 'good');
    });

    test('missing totals is rejected; missing numbers default to zero', () {
      expect(() => OrgDashboard.fromJson({'recent_analyses': []}),
          throwsFormatException);
      final d = OrgDashboard.fromJson({'totals': <String, dynamic>{}});
      expect(d.totals.projects, 0);
      expect(d.totals.complianceScore, isNull);
      expect(d.attentionProjects, isEmpty);
    });
  });

  group('OrgDashboardProvider', () {
    late FakeDashboardService service;
    late OrgDashboardProvider provider;

    setUp(() {
      service = FakeDashboardService()
        ..result = OrgDashboard.fromJson(dashboardJson());
      provider = OrgDashboardProvider(service);
    });

    test('loads data for an organisation', () async {
      await provider.load('o1');
      expect(provider.status, DashboardStatus.ready);
      expect(provider.orgId, 'o1');
      expect(provider.data?.totals.projects, 3);
    });

    test('switching organisation clears the previous figures immediately',
            () async {
          await provider.load('o1');
          final pending = provider.load('o2');
          expect(provider.orgId, 'o2');
          expect(provider.data, isNull);
          await pending;
          expect(provider.data, isNotNull);
        });

    test('error keeps the previous data of the same organisation', () async {
      await provider.load('o1');
      service.error = const ApiException(ApiErrorKind.network, 'down');
      await provider.load('o1');
      expect(provider.status, DashboardStatus.error);
      expect(provider.error?.message, 'down');
      expect(provider.data, isNotNull);
    });

    test('a slow earlier load cannot overwrite a newer one', () async {
      final slow = Completer<OrgDashboard>();
      final fast = Completer<OrgDashboard>();
      service.loadOverride = (org) => org == 'a' ? slow.future : fast.future;
      final first = provider.load('a');
      final second = provider.load('b');
      fast.complete(OrgDashboard.fromJson(dashboardJson()));
      await second;
      slow.complete(OrgDashboard.fromJson({'totals': <String, dynamic>{}}));
      await first;

      expect(provider.orgId, 'b');
      expect(provider.data?.totals.projects, 3);
    });

    test('reset clears everything', () async {
      await provider.load('o1');
      provider.reset();
      expect(provider.orgId, isNull);
      expect(provider.data, isNull);
      expect(provider.status, DashboardStatus.idle);
    });
  });
}