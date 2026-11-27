import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosmate/core/widgets/zoomable_image.dart';

void main() {
  testWidgets('opens a zoom viewer and supports back navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZoomableImage(
            imageProvider: MemoryImage(Uint8List(0)),
            child: const Text('Preview'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close image'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close image'), findsNothing);
  });
}
