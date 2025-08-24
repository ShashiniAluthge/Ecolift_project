class PickupAlreadyAcceptedException implements Exception {
  final String message;
  PickupAlreadyAcceptedException(
      [this.message = 'Pickup request already accepted']);
  @override
  String toString() => message;
}
