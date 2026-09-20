class AppConstants {
  static const String appName = 'SurplusBite';
  static const String appTagline = 'Reduce Waste, Feed Communities';

  static const String usersCollection = 'users';
  static const String listingsCollection = 'listings';
  static const String ordersCollection = 'orders';
  static const String reviewsCollection = 'reviews';
  static const String messagesCollection = 'messages';
  static const String chatRoomsCollection = 'chat_rooms';

  static const List<String> categories = [
    'All',
    'Bakery',
    'Restaurant',
    'Grocery',
    'Produce',
    'Dairy',
    'Prepared Meals',
    'Beverages',
    'Snacks',
  ];

  static const List<String> dietaryTags = [
    'Vegetarian',
    'Vegan',
    'Gluten-Free',
    'Halal',
    'Kosher',
    'Dairy-Free',
    'Nut-Free',
    'Organic',
  ];

  static const List<String> units = [
    'pieces',
    'kg',
    'g',
    'liters',
    'portions',
    'boxes',
    'bags',
  ];

  static const String statusPending = 'pending';
  static const String statusConfirmed = 'confirmed';
  static const String statusPickedUp = 'picked_up';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  static const String listingAvailable = 'available';
  static const String listingReserved = 'reserved';
  static const String listingExpired = 'expired';
  static const String listingCompleted = 'completed';

  static const String roleConsumer = 'consumer';
  static const String roleProvider = 'provider';
  static const String roleNGO = 'ngo';

  static const int maxImagesPerListing = 5;
  static const int maxDescriptionLength = 500;
  static const double defaultSearchRadius = 5.0;
  static const double maxSearchRadius = 25.0;
  static const double co2PerKgFood = 2.5;
}
