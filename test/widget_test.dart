import 'package:flutter_test/flutter_test.dart';
import 'package:meus_livros/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('abre o app com as abas do gerenciador de livros', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MeusLivrosApp());
    await tester.pumpAndSettle();

    expect(find.text('Meus Livros'), findsOneWidget);
    expect(find.text('Lidos'), findsOneWidget);
    expect(find.text('Desejados'), findsOneWidget);
    expect(find.text('Top 5'), findsOneWidget);
  });
}
