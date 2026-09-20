import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:surplus_bite/providers/listing_provider.dart';

void main() {
  group('listingFilterProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('starts with the default filter', () {
      expect(container.read(listingFilterProvider), const ListingFilter());
    });

    test('setCategory updates the category', () {
      container.read(listingFilterProvider.notifier).setCategory('Meals');
      expect(container.read(listingFilterProvider).category, 'Meals');
    });

    test('setMaxDistance updates the radius', () {
      container
          .read(listingFilterProvider.notifier)
          .setMaxDistance(5);
      expect(container.read(listingFilterProvider).maxDistance, 5);
    });

    test('toggleDietaryTag adds and removes tags', () {
      final notifier = container.read(listingFilterProvider.notifier);

      notifier.toggleDietaryTag('veg');
      expect(container.read(listingFilterProvider).dietaryTags, ['veg']);

      notifier.toggleDietaryTag('spicy');
      expect(container.read(listingFilterProvider).dietaryTags, ['veg', 'spicy']);

      notifier.toggleDietaryTag('veg');
      expect(container.read(listingFilterProvider).dietaryTags, ['spicy']);
    });

    test('reset restores defaults', () {
      final notifier = container.read(listingFilterProvider.notifier);
      notifier
        ..setCategory('Meals')
        ..setMaxDistance(10)
        ..toggleDietaryTag('veg')
        ..reset();

      expect(container.read(listingFilterProvider), const ListingFilter());
    });
  });
}