class PickupActivity {
  final List<String> wasteTypes;
  final String location;
  final String selectionType;
  final DateTime timestamp;

  PickupActivity({
    required this.wasteTypes,
    required this.location,
    required this.selectionType,
    required this.timestamp,
  });
}
