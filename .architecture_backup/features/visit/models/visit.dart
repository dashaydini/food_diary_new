class Visit {
  final String id;

  final String placeName;

  final String placeType;

  final String city;

  final DateTime visitDate;

  final double food;

  final double service;

  final double atmosphere;

  final double cleanliness;

  final double valueForMoney;

  final String notes;

  final bool wouldReturn;

  final int pricePerPerson;

  final List<String> dishes;

  final List<String> photos;

  const Visit({
    required this.id,
    required this.placeName,
    required this.placeType,
    required this.city,
    required this.visitDate,
    required this.food,
    required this.service,
    required this.atmosphere,
    required this.cleanliness,
    required this.valueForMoney,
    required this.notes,
    required this.wouldReturn,
    required this.pricePerPerson,
    required this.dishes,
    required this.photos,
  });

  double get average =>
      (food + service + atmosphere + cleanliness + valueForMoney) / 5;
}
