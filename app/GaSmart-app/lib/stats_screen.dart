import 'package:GaSmart/models/spesa.dart';
import 'package:GaSmart/utils/db.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:month_year_picker/month_year_picker.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

extension DateTimeExtension on DateTime {
  int get lastDayOfMonth => DateTime(year, month + 1, 0).day;

  DateTime get lastDateOfMonth => DateTime(year, month + 1, 0);
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime firstDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<Spesa> speseAttuali = [];
  List<Spesa> spesePassate = [];
  List<FlSpot> points1 = [];
  List<FlSpot> points2 = [];

  Future<DateTime> selectMonth(BuildContext context, DateTime d) async {
    final DateTime? picked = await showMonthYearPicker(
      context: context,
      initialDate: d,
      firstDate: DateTime(2019),
      lastDate: DateTime(2029),
    );
    if (picked == null) return firstDate;
    return picked;
  }

  SideTitles get _bottomTitles => SideTitles(
        showTitles: true,
        getTitlesWidget: (value, meta) {
          return Text(value.toStringAsFixed(0));
        },
      );

  SideTitles get _sideTitles => SideTitles(
        showTitles: true,
        reservedSize: 35,
        getTitlesWidget: (value, meta) {
          return Padding(
              padding: EdgeInsets.fromLTRB(5, 0, 0, 0),
              child: Text("€" + value.toStringAsFixed(0)));
        },
      );

  Future<void> _loadSpese() async {
    List<Map<String, dynamic>> s =
        await DB.getSpese(firstDate.month, firstDate.year);
    List<Map<String, dynamic>> s2 = [];
    if (firstDate.month - 1 <= 0) {
      s2 = await DB.getSpese(12, firstDate.year - 1);
    } else {
      s2 = await DB.getSpese(firstDate.month - 1, firstDate.year);
    }
    setState(() {
      speseAttuali = s.map((e) => Spesa.fromMap(e)).toList();
      spesePassate = s2.map((e) => Spesa.fromMap(e)).toList();

      points1 =
          speseAttuali.map((e) => FlSpot(e.day.toDouble(), e.amount)).toList();
      points2 =
          spesePassate.map((e) => FlSpot(e.day.toDouble(), e.amount)).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSpese();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: GestureDetector(
            onTap: () {
              FocusScope.of(context).requestFocus(FocusNode());
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 20, 16.0, 0),
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(
                    child: Text('Grafico spese',
                        style: Theme.of(context).textTheme.headlineSmall)),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                          readOnly: true,
                          controller: TextEditingController(
                              text:
                                  "${DateTime.parse(firstDate.toString()).month}/${DateTime.parse(firstDate.toString()).year}"),
                          decoration: InputDecoration(
                            suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_month),
                                onPressed: () async {
                                  var d = await selectMonth(context, firstDate);
                                  setState(() {
                                    firstDate = DateTime(
                                        d.year, d.month, firstDate.day);
                                    _loadSpese();
                                  });
                                }),
                            helperText: 'Seleziona il mese',
                            filled: true,
                          )),
                    ),
                  ]),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        minX: 1,
                        // maxX: 31,
                        minY: 5,
                        // maxY: 99,
                        lineBarsData: [
                          LineChartBarData(
                              spots: points1,
                              isCurved: true,
                              color: Colors.greenAccent),
                          LineChartBarData(
                              spots: points2,
                              isCurved: true,
                              color: Colors.purple,
                              dashArray: [5]),
                        ],
                        borderData: FlBorderData(
                            border: const Border(
                                bottom: BorderSide(), left: BorderSide())),
                        gridData: const FlGridData(
                            show: true, drawVerticalLine: false),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(sideTitles: _bottomTitles),
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: _sideTitles),
                        ),
                      ),
                    ),
                  ),
                ),
                // SliverToBoxAdapter(
                //   child: MySeparator(color: Colors.purple),
                // ),
                SliverToBoxAdapter(
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mese selezionato'),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          0, 5, MediaQuery.of(context).size.width * .8, 0.0),
                      child: const Divider(
                        color: Colors.greenAccent,
                        height: 3,
                      ),
                    ),
                    const Text('Mese precedente'),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          0, 5, MediaQuery.of(context).size.width * .8, 0.0),
                      child: const Divider(
                        color: Colors.purple,
                        height: 3,
                      ),
                    )
                  ],
                )),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
                SliverToBoxAdapter(
                    child: OutlinedButton.icon(
                  onPressed: () {
                    openFullscreenDialog(context)
                        .then((value) async => await _loadSpese());
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi spesa'),
                )),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverToBoxAdapter(
                  child: FilledButton(
                    onPressed: () async {
                      await DB.deleteSpeseMese(firstDate.month, firstDate.year);
                      await _loadSpese();
                    },
                    child: const Text('Cancella spese di questo mese'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverToBoxAdapter(
                  child: FilledButton(
                    onPressed: () async {
                      await DB.deleteSpese();
                      await _loadSpese();
                    },
                    child: const Text('Azzera tutto'),
                  ),
                )
              ]),
            )));
  }
}

class MySeparator extends StatelessWidget {
  const MySeparator({Key? key, this.height = 2, this.color = Colors.black})
      : super(key: key);
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        final dashHeight = height;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Row(
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          // direction: Axis.horizontal,
        );
      },
    );
  }
}

Future<void> openFullscreenDialog(BuildContext context) {
  double amount = 0.0, liters = 0.0;
  DateTime date = DateTime.now();
  TextEditingController textController1 = TextEditingController();
  TextEditingController textController2 = TextEditingController();

  Future<DateTime> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2015, 8),
        lastDate: DateTime(2101));
    if (picked == null) return DateTime.now();
    return picked;
  }

  return showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
            return Dialog.fullscreen(
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).requestFocus(FocusNode());
                },
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Scaffold(
                    appBar: AppBar(
                      title: const Text('Aggiungi spesa'),
                      centerTitle: false,
                      leading: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      actions: [
                        TextButton(
                          child: const Text('Close'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    body: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                            child: TextField(
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setState(() =>
                                  amount = double.parse(textController1.text)),
                              controller: textController1,
                              decoration: InputDecoration(
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => textController1.clear(),
                                ),
                                labelText: 'Spesa in €',
                                filled: true,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                            child: SizedBox(
                              child: TextField(
                                keyboardType: TextInputType.number,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                onChanged: (val) => setState(() => liters =
                                    double.parse(textController2.text)),
                                controller: textController2,
                                decoration: InputDecoration(
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => textController2.clear(),
                                  ),
                                  labelText: 'Litri',
                                  filled: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                            child: TextField(
                                readOnly: true,
                                controller: TextEditingController(
                                    text:
                                        "${date.day}/${date.month}/${date.year}"),
                                decoration: InputDecoration(
                                  suffixIcon: IconButton(
                                      icon: const Icon(Icons.calendar_month),
                                      onPressed: () async {
                                        var d = await selectDate(context);
                                        setState(() => date = d);
                                      }),
                                  helperText: 'data',
                                  filled: true,
                                )),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton(
                                  onPressed: () {
                                    DB.insertSpesa(Spesa(amount, liters,
                                            date.day, date.month, date.year)
                                        .toMap());
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Salva'),
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          }));
}
