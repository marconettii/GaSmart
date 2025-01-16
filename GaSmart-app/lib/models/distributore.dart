class Distributore {
  String nome;
  String brand;
  double lat;
  double lng;
  Map<String, double> prezzi;

  static Distributore fromJson(dynamic m) => Distributore(
      m["Nome"] as String,
      m["Brand"] as String,
      m["Latitudine"] as double,
      m["Longitudine"] as double,
      m["prezzi"] as Map<String, double>);

  Distributore(
    this.nome,
    this.brand,
    this.lat,
    this.lng,
    this.prezzi,
  );
}
