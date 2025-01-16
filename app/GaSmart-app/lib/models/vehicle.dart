import 'enums.dart';

class Vehicle {
  int id;
  String marca;
  String modello;
  DateTime anno;
  int kmL = 6; // kmL = mpG / 2.352 = kmL
  bool editable;
  ClassiVeicolo classe;
  TipiCarburante carburante;

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "marca": marca,
      "modello": modello,
      "anno": anno.toString(),
      "kmL": 6,
      "editable": editable ? 1 : 0,
      "classe": classe.toString().replaceAll("ClassiVeicolo.", ""),
      "carburante": carburante.toString().replaceAll("TipiCarburante.", "")
    };
  }

  static Vehicle fromMap(Map<String, dynamic> m) {
    return Vehicle(
        m["id"] as int,
        m["marca"] as String,
        m["modello"] as String,
        DateTime.parse(m["anno"] as String),
        m["kmL"] as int,
        (m["editable"] as int) == 1 ? true : false,
        EnumConverter.tipoCarburanteFromStr(m["carburante"] as String),
        ClassiVeicolo.Test.fromString(m["classe"] as String));
  }

  Vehicle(this.id, this.marca, this.modello, this.anno, this.kmL, this.editable,
      this.carburante, this.classe);
}
