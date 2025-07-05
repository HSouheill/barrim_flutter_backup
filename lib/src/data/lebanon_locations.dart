class LebanonLocation {
  final String name;
  final List<String> cities;

  LebanonLocation({required this.name, required this.cities});
}

final List<LebanonLocation> lebanonDistricts = [
  LebanonLocation(
    name: 'Beirut',
    cities: ['Beirut'],
  ),
  LebanonLocation(
    name: 'Mount Lebanon',
    cities: [
      'Baabda',
      'Aley',
      'Chouf',
      'Jbeil',
      'Keserwan',
      'Metn',
    ],
  ),
  LebanonLocation(
    name: 'North Lebanon',
    cities: [
      'Akkar',
      'Batroun',
      'Bsharri',
      'Koura',
      'Miniyeh-Danniyeh',
      'Tripoli',
      'Zgharta',
    ],
  ),
  LebanonLocation(
    name: 'South Lebanon',
    cities: [
      'Jezzine',
      'Sidon',
      'Tyre',
      'Nabatieh',
    ],
  ),
  LebanonLocation(
    name: 'Bekaa',
    cities: [
      'Baalbek',
      'Hermel',
      'Rashaya',
      'Western Bekaa',
      'Zahle',
    ],
  ),
  LebanonLocation(
    name: 'Nabatieh',
    cities: [
      'Bint Jbeil',
      'Hasbaya',
      'Marjeyoun',
      'Nabatieh',
    ],
  ),
]; 