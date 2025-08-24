class Customer {
  final String name;
  final String email;
  final String phone;
  final String? addressNo;
  final String? street;
  final String? city;
  final String? district;
  final String? password;

  Customer({
    required this.name,
    required this.email,
    required this.phone,
    this.addressNo,
    this.street,
    this.city,
    this.district,
    this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'role': 'customer',
      'address': {
        'addressNo': addressNo,
        'street': street,
        'city': city,
        'district': district,
      },
    };
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>?;
    return Customer(
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      addressNo: address?['addressNo'] as String?,
      street: address?['street'] as String?,
      city: address?['city'] as String?,
      district: address?['district'] as String?,
    );
  }

  Customer copyWith({
    String? name,
    String? email,
    String? phone,
    String? addressNo,
    String? street,
    String? city,
    String? district,
    String? password,
  }) {
    return Customer(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      addressNo: addressNo ?? this.addressNo,
      street: street ?? this.street,
      city: city ?? this.city,
      district: district ?? this.district,
      password: password ?? this.password,
    );
  }
}
