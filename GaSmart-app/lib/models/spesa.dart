class Spesa {
  double amount;
  double liters;
  int day;
  int month;
  int year;

  Map<String, dynamic> toMap() => {
        "amount": amount,
        "liters": liters,
        "day": day,
        "month": month,
        "year": year
      };

  static Spesa fromMap(Map<String, dynamic> m) => Spesa(
      m["amount"] as double,
      m["liters"] as double,
      m["day"] as int,
      m["month"] as int,
      m["year"] as int);

  Spesa(this.amount, this.liters, this.day, this.month, this.year);
}
