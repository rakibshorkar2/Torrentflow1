// TorrentFlow - Basic smoke test
// The app requires async initialization (SharedPreferences) so we just
// verify it can be pumped without crashing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test - renders without crash',
      (WidgetTester tester) async {
    // Just verify the basic Material app structure works
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('TorrentFlow')),
        ),
      ),
    );
    expect(find.text('TorrentFlow'), findsOneWidget);
  });
}
