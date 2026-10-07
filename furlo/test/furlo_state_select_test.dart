import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('pets view keeps a stable identity until the pet list changes', () async {
    final repository = WebPetRepository();
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
    final state = FurloState(repository);
    await state.load();

    final view = state.pets;
    expect(identical(view, state.pets), isTrue);
    expect(
      () => state.pets.add(Pet(name: 'Sneaky', species: 'Cat')),
      throwsUnsupportedError,
    );

    // Notifying without touching the list keeps the same view instance.
    state.selectPet(state.pets.first);
    expect(identical(view, state.pets), isTrue);

    await state.addPet(Pet(name: 'Miso', species: 'Cat'));
    expect(identical(view, state.pets), isFalse);
    expect(state.pets.length, 2);

    state.resetForSession();
    expect(identical(view, state.pets), isFalse);
    expect(state.pets, isEmpty);
    state.dispose();
  });

  testWidgets(
    'select-based dependents skip rebuilds when nothing they use changed',
    (tester) async {
      final repository = WebPetRepository();
      await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
      await repository.addPet(Pet(name: 'Miso', species: 'Cat'));
      final state = FurloState(repository);
      await state.load();

      var builds = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider<FurloState>.value(
          value: state,
          child: Builder(
            builder: (context) {
              final pets = context.select<FurloState, List<Pet>>(
                (s) => s.pets,
              );
              final selectedId = context.select<FurloState, String?>(
                (s) => s.selectedPet?.id,
              );
              builds++;
              return Text(
                '${pets.length}:${selectedId ?? 'none'}',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );
      expect(builds, 1);
      expect(
        find.text('2:${state.selectedPet?.id}'),
        findsOneWidget,
        reason: 'initial render shows both pets and the selection',
      );

      // Re-selecting the same pet notifies but changes neither watched value.
      state.selectPet(state.pets.first);
      await tester.pump();
      expect(builds, 1);

      // A different selection rebuilds.
      state.selectPet(state.pets.last);
      await tester.pump();
      expect(builds, 2);
      expect(find.text('2:${state.pets.last.id}'), findsOneWidget);

      // Growing the pet list rebuilds.
      await state.addPet(Pet(name: 'Nemo', species: 'Fish'));
      await tester.pump();
      expect(builds, 3);
      expect(
        find.text('3:${state.selectedPet?.id}'),
        findsOneWidget,
        reason: 'addPet selects the new pet',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
}
