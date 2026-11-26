import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosmate/core/widgets/owner_information_card.dart';
import 'package:kosmate/models/user_model.dart';

void main() {
  testWidgets('shows owner name and contact details', (tester) async {
    const owner = UserModel(
      userId: 7,
      name: 'Owner Name',
      email: 'owner@example.com',
      phone: '+628123456789',
      role: UserRole.owner,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OwnerInformationCard(owner: owner)),
      ),
    );

    expect(find.text('Owner Information'), findsOneWidget);
    expect(find.text('Owner Name'), findsOneWidget);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.text('+628123456789'), findsOneWidget);
  });
}
