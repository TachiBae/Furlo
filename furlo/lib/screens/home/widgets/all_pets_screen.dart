part of '../home_screen.dart';

// The "See all" pet list opened from the dashboard.

class _AllPetsScreen extends StatelessWidget {
  const _AllPetsScreen({required this.onAddPet});
  final VoidCallback onAddPet;

  @override
  Widget build(BuildContext context) {
    final pets = context.select<FurloState, List<Pet>>((s) => s.pets);
    final selectedPetId = context.select<FurloState, String?>(
      (s) => s.selectedPet?.id,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('My Pets')),
      body: pets.isEmpty
          ? RecordEmptyState(
              icon: Icons.pets_outlined,
              title: 'No pets yet',
              message: 'Add your first pet to start tracking their care.',
              actionLabel: 'Add pet',
              onAction: onAddPet,
            )
          : GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: pets.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) => _PetTile(
                pet: pets[index],
                selected: pets[index].id == selectedPetId,
                width: double.infinity,
                onTap: () => Navigator.of(context).pop(pets[index]),
              ),
            ),
    );
  }
}
