import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aux_music/main.dart';

void main() {
  testWidgets('App starts and shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AuxMusicApp()));
    await tester.pumpAndSettle();

    expect(find.text('Aux'), findsOneWidget);
    expect(find.text('Host a Party'), findsOneWidget);
    expect(find.text('Join a Party'), findsOneWidget);
  });
}
