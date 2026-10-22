// import 'package:checkmydeps/features/dependency_analysis/models/analysis_result.dart';
// import 'package:checkmydeps/features/projects/widgets/dependency_inventory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dependency_analysis/models/analysis_result.dart';
import 'package:frontend/features/projects/widgets/dependency_inventory.dart';

DependencyResult dep(String name, String risk, int score, int rank,
    {bool failed = false}) =>
    DependencyResult.fromJson({
      'name': name,
      'ecosystem': 'PyPI',
      'declared_version': '1.0.0',
      'status': failed ? 'failed' : 'analyzed',
      'risk_rank': rank,
      if (failed) 'error': 'lookup failed',
      if (!failed) ...{
        'governance': {'score': score, 'risk_level': risk},
        'maintenance': {
          'prediction': {'status': 'Maintained'},
        },
      },
    });

/// The test font (Ahem) is far wider than the real UI font, so fixed-width
/// badges can "overflow" here although they fit in the app. These tests check
/// filtering, searching and tapping, not pixel layout, so overflow reports are
/// discarded; any other exception is still raised.
void ignoreTestFontOverflow(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception != null && !exception.toString().contains('overflowed')) {
    throw exception;
  }
}

void main() {
  Future<List<String>> pump(
      WidgetTester tester, List<DependencyResult> deps) async {
    tester.view.physicalSize = const Size(1600, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DependencyInventory(
              dependencies: deps,
              onOpen: (d) => opened.add(d.name),
            ),
          ),
        ),
      ),
    );
    ignoreTestFontOverflow(tester);
    return opened;
  }

  testWidgets('shows every package with filter counts', (tester) async {
    await pump(tester, [
      dep('alpha', 'HIGH', 40, 1),
      dep('bravo', 'HIGH', 55, 2),
      dep('charlie', 'LOW', 95, 3),
      dep('delta', 'LOW', 90, 0, failed: true),
    ]);

    for (final name in ['alpha', 'bravo', 'charlie', 'delta']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('All (4)'), findsOneWidget);
    expect(find.text('High (2)'), findsOneWidget);
    expect(find.text('Low (1)'), findsOneWidget); // the failed one is not counted as LOW
    expect(find.text('Critical (0)'), findsOneWidget);
    expect(find.text('Failed (1)'), findsOneWidget);
  });

  testWidgets('risk filter and search narrow the list', (tester) async {
    await pump(tester, [
      dep('alpha', 'HIGH', 40, 1),
      dep('bravo', 'HIGH', 55, 2),
      dep('charlie', 'LOW', 95, 3),
    ]);

    await tester.tap(find.text('High (2)'));
    await tester.pump();
    ignoreTestFontOverflow(tester);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('bravo'), findsOneWidget);
    expect(find.text('charlie'), findsNothing);

    await tester.tap(find.text('All (3)'));
    await tester.pump();
    ignoreTestFontOverflow(tester);
    await tester.enterText(find.byType(TextField), 'char');
    await tester.pump();
    ignoreTestFontOverflow(tester);
    expect(find.text('charlie'), findsOneWidget);
    expect(find.text('bravo'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    ignoreTestFontOverflow(tester);
    expect(find.text('No packages match your filters.'), findsOneWidget);
  });

  testWidgets('tapping a package opens it', (tester) async {
    final opened = await pump(tester, [dep('alpha', 'HIGH', 40, 1)]);
    await tester.tap(find.text('alpha'));
    await tester.pump();
    ignoreTestFontOverflow(tester);
    expect(opened, ['alpha']);
  });

  testWidgets('an analysis with no dependencies shows an empty state',
          (tester) async {
        await pump(tester, const []);
        expect(find.text('This analysis contains no dependencies.'), findsOneWidget);
      });
}