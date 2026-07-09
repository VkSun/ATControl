import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/models/invitation_code.dart';
import 'package:atcontrol/screens/users/providers.dart';
import 'package:atcontrol/screens/users/users_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('телефон: список пользователей из мокнутого usersProvider',
      (tester) async {
    await pumpApp(tester, const UsersScreen(), overrides: [
      usersProvider.overrideWith((ref) async => [
            adminRole(),
            role(id: 'r2', fullName: 'Сидоров Сидор'),
            role(id: 'r3', fullName: 'Блокированный Б.', isActive: false),
          ]),
      invitationsProvider.overrideWith((ref) async => <InvitationCode>[]),
    ]);

    expect(find.text('Админ Админов'), findsOneWidget);
    expect(find.text('Сидоров Сидор'), findsOneWidget);
    expect(find.text('Блокированный Б.'), findsOneWidget);
    // Статус-бейджи: активные и заблокированный.
    expect(find.text('Активен'), findsNWidgets(2));
    expect(find.text('Блок.'), findsOneWidget);
  });

  testWidgets('телефон: вкладка «Приглашения» — карточки кодов',
      (tester) async {
    await pumpApp(tester, const UsersScreen(), overrides: [
      usersProvider.overrideWith((ref) async => [adminRole()]),
      invitationsProvider.overrideWith((ref) async => [
            InvitationCode(
              id: 'i1',
              code: 'AAAA-BBBB-CCCC',
              fullName: 'Новичок Н.',
              position: 'Водитель',
              isUsed: false,
              permFullAccess: false,
              permEdit: false,
              permExecute: false,
              permRead: true,
              permWrite: false,
              permOwnOnly: false,
              expiresAt: DateTime.now().add(const Duration(days: 7)),
              createdAt: DateTime.now(),
            ),
          ]),
    ]);

    await tester.tap(find.text('Приглашения'));
    await tester.pumpAndSettle();

    expect(find.text('AAAA-BBBB-CCCC'), findsOneWidget);
    expect(find.text('Новичок Н.'), findsOneWidget);
    expect(find.text('Водитель'), findsOneWidget);
    expect(find.text('Активен'), findsOneWidget);
    expect(find.text('Отозвать'), findsOneWidget);
  });

  testWidgets('пустой список: заглушка', (tester) async {
    await pumpApp(tester, const UsersScreen(), overrides: [
      usersProvider.overrideWith((ref) async => []),
      invitationsProvider.overrideWith((ref) async => <InvitationCode>[]),
    ]);

    expect(find.text('Нет пользователей'), findsOneWidget);
  });
}
