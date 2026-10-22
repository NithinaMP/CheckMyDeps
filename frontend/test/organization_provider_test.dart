// import 'package:checkmydeps/core/services/api_client.dart';
// import 'package:checkmydeps/features/organization/models/organization.dart';
// import 'package:checkmydeps/features/organization/providers/organization_provider.dart';
// import 'package:checkmydeps/features/organization/services/organization_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/api_client.dart';
import 'package:frontend/features/organization/models/organization.dart';
import 'package:frontend/features/organization/providers/organization_provider.dart';
import 'package:frontend/features/organization/services/organisation_service.dart';

// NOTE: replace `checkmydeps` with the `name:` in your pubspec.yaml if different.

OrgMembership membership(String id, String name, OrgRole role) => OrgMembership(
  organization: Organization(id: id, name: name),
  role: role,
);

class FakeOrgService extends OrganizationService {
  FakeOrgService() : super(ApiClient());

  List<OrgMembership> listResult = [];
  ApiException? listError;
  ApiException? createError;
  Future<List<OrgMembership>> Function()? listOverride;

  @override
  Future<List<OrgMembership>> listMine() async {
    if (listOverride != null) return listOverride!();
    if (listError != null) throw listError!;
    return listResult;
  }

  @override
  Future<OrgMembership> create(String name) async {
    if (createError != null) throw createError!;
    return membership('new-id', name, OrgRole.admin);
  }

  @override
  Future<OrgMembership> rename(String orgId, String name) async =>
      membership(orgId, name, OrgRole.admin);
}

void main() {
  group('OrgRole', () {
    test('hierarchy', () {
      expect(OrgRole.admin.atLeast(OrgRole.lead), isTrue);
      expect(OrgRole.lead.atLeast(OrgRole.admin), isFalse);
      expect(OrgRole.developer.atLeast(OrgRole.developer), isTrue);
      expect(OrgRole.developer.atLeast(OrgRole.lead), isFalse);
    });

    test('tryParse accepts only known roles', () {
      expect(OrgRole.tryParse('admin'), OrgRole.admin);
      expect(OrgRole.tryParse('owner'), isNull);
      expect(OrgRole.tryParse('ADMIN'), isNull);
      expect(OrgRole.tryParse(null), isNull);
      expect(OrgRole.tryParse(3), isNull);
    });

    test('OrgMembership.fromJson rejects unknown role / bad payload', () {
      expect(
            () => OrgMembership.fromJson({'id': 'a', 'name': 'A', 'role': 'owner'}),
        throwsFormatException,
      );
      expect(() => OrgMembership.fromJson({'name': 'A', 'role': 'admin'}),
          throwsFormatException);
      final m = OrgMembership.fromJson(
          {'id': 'a', 'name': 'A', 'role': 'lead', 'created_at': '2026-10-20T10:00:00Z'});
      expect(m.role, OrgRole.lead);
      expect(m.organization.createdAt, isNotNull);
    });
  });

  group('OrganizationProvider', () {
    late FakeOrgService service;
    late OrganizationProvider provider;

    setUp(() {
      service = FakeOrgService()
        ..listResult = [
          membership('o1', 'Acme', OrgRole.admin),
          membership('o2', 'Beta', OrgRole.developer),
        ];
      provider = OrganizationProvider(service);
    });

    test('starts in the Personal workspace', () async {
      await provider.load();
      expect(provider.status, OrgLoadStatus.ready);
      expect(provider.memberships, hasLength(2));
      expect(provider.isOrgWorkspace, isFalse);
      expect(provider.hasRole(OrgRole.developer), isFalse);
    });

    test('can only switch to organisations the backend returned', () async {
      await provider.load();
      expect(provider.switchToOrganization('not-mine'), isFalse);
      expect(provider.isOrgWorkspace, isFalse);

      expect(provider.switchToOrganization('o2'), isTrue);
      expect(provider.activeRole, OrgRole.developer);
      expect(provider.hasRole(OrgRole.developer), isTrue);
      expect(provider.hasRole(OrgRole.lead), isFalse);

      provider.switchToPersonal();
      expect(provider.isOrgWorkspace, isFalse);
    });

    test('create makes the new organisation active as admin', () async {
      await provider.load();
      expect(await provider.createOrganization('Gamma'), isTrue);
      expect(provider.activeMembership?.name, 'Gamma');
      expect(provider.activeRole, OrgRole.admin);
      expect(provider.memberships.first.id, 'new-id');
    });

    test('create failure keeps state and exposes the error', () async {
      await provider.load();
      service.createError =
      const ApiException(ApiErrorKind.conflict, 'limit', statusCode: 409);
      expect(await provider.createOrganization('Gamma'), isFalse);
      expect(provider.actionError?.message, 'limit');
      expect(provider.memberships, hasLength(2));
      expect(provider.isOrgWorkspace, isFalse);
      expect(provider.isBusy, isFalse);
    });

    test('load error is surfaced and Personal workspace stays usable', () async {
      service.listError = const ApiException(ApiErrorKind.network, 'down');
      await provider.load();
      expect(provider.status, OrgLoadStatus.error);
      expect(provider.loadError?.message, 'down');
      expect(provider.isOrgWorkspace, isFalse);
    });

    test('reload drops an active organisation the user no longer belongs to',
            () async {
          await provider.load();
          provider.switchToOrganization('o1');
          service.listResult = [membership('o2', 'Beta', OrgRole.developer)];
          await provider.load();
          expect(provider.isOrgWorkspace, isFalse);
        });

    test('rename updates the active organisation', () async {
      await provider.load();
      provider.switchToOrganization('o1');
      expect(await provider.renameActive('Acme 2'), isTrue);
      expect(provider.activeMembership?.name, 'Acme 2');
    });

    test('reset clears everything and discards in-flight loads', () async {
      service.listOverride = () async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return [membership('o1', 'Acme', OrgRole.admin)];
      };
      final pending = provider.load();
      provider.reset(); // e.g. user signs out while loading
      await pending;
      expect(provider.memberships, isEmpty);
      expect(provider.status, OrgLoadStatus.idle);
      expect(provider.isOrgWorkspace, isFalse);
    });
  });
}
