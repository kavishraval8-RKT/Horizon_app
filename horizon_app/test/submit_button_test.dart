import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horizon_app/theme.dart';

void main() {
  testWidgets('a second tap while the first is still sending does nothing', (tester) async {
    var calls = 0;
    final server = Completer<void>(); // a slow network: the request hasn't answered yet

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SubmitButton(
          onPressed: () {
            calls++;
            return server.future;
          },
          child: const Text('Check Out'),
        ),
      ),
    ));

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget); // feedback while it works
    expect(find.text('Check Out'), findsNothing);

    await tester.tap(find.byType(ElevatedButton)); // impatient second tap
    await tester.pump();
    expect(calls, 1);

    server.complete(); // server answers
    await tester.pump();
    expect(find.text('Check Out'), findsOneWidget); // usable again (e.g. after an error)
  });
}
