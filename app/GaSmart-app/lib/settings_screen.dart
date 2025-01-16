import 'dart:convert';

import 'package:GaSmart/models/enums.dart';
import 'package:GaSmart/models/vehicle.dart';
import 'package:GaSmart/utils/db.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:localstorage/localstorage.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

const List<String> carburanti = <String>['Diesel', 'Benzina', 'GPL'];

class _SettingsScreenState extends State<SettingsScreen> {
  List<Vehicle> veicoli = <Vehicle>[];
  String selectedVeicolo = "";
  bool risparmio = false;
  bool inquinamento = true;
  int raggio = 20;
  late dynamic makes;
  bool showTerms = false;

  Future<void> _loadSettings() async {
    var st = (await DB.getSettings())[0];
    await _loadVeicoli();
    String mks = await _getMakes();
    setState(() {
      makes = jsonDecode(mks);
      selectedVeicolo = st["veicolo"].toString();
      print(selectedVeicolo);
      risparmio = (st["risparmio"] as int) == 1 ? true : false;
      inquinamento = (st["inquinamento"] as int) == 1 ? true : false;
      raggio = st["raggio"] as int;
    });
  }

  Future<void> _loadVeicoli() async {
    List<Map<String, dynamic>> v = await DB.getVehicles();
    setState(() => veicoli = v.map((e) => Vehicle.fromMap(e)).toList());
  }

  Future<String> _getMakes() async {
    final LocalStorage storage = LocalStorage('stor.json');
    try {
      await storage.ready;
      if (storage.getItem('makes') != null) {
        return storage.getItem('makes') as String;
      }
      var makesResponse = await http.get(Uri.parse(
          "https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/all-vehicles-model/records?select=make&group_by=make"));
      await storage.setItem('makes', makesResponse.body);
      return makesResponse.body;
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Errore inaspettato.')));
    }
    return "";
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Errore inaspettato.')));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 20, 16.0, 0),
                child: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 20, 16.0, 0),
                  child: DropdownMenu<String>(
                    width: MediaQuery.of(context).size.width - 32,
                    inputDecorationTheme:
                        const InputDecorationTheme(filled: true),
                    initialSelection: selectedVeicolo,
                    label: Text("Il tuo veicolo"),
                    onSelected: (value) {
                      setState(() {
                        selectedVeicolo = value!;
                      });
                    },
                    requestFocusOnTap: true,
                    dropdownMenuEntries:
                        veicoli.map<DropdownMenuEntry<String>>((value) {
                      return DropdownMenuEntry<String>(
                          value: value.id.toString(),
                          label: "${value.marca} ${value.modello}",
                          trailingIcon: value.editable
                              ? Row(children: [
                                  IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () {
                                        if (value.id.toString() ==
                                            selectedVeicolo) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content:
                                                      Text("Cannot do this")));
                                          return;
                                        }
                                        DB
                                            .deleteVehicle(value.id)
                                            .then((value) async {
                                          await _loadSettings();
                                        });
                                      }),
                                  IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () {
                                        GestureBinding.instance
                                            .handlePointerEvent(
                                          const PointerDownEvent(
                                              position: Offset(10, 10)),
                                        );
                                        openFullscreenDialog(
                                                context,
                                                true,
                                                makes,
                                                veicoli
                                                    .firstWhere((element) =>
                                                        element.id == value.id)
                                                    .toMap(),
                                                setState)
                                            .then((value) async {
                                          await _loadSettings();
                                        });
                                      })
                                ])
                              : null);
                    }).toList(),
                  )),
            ),
            SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 20, 16.0, 0),
                  child: Row(
                    children: [
                      Switch(
                        value: risparmio,
                        onChanged: (value) {
                          setState(() {
                            risparmio = value;
                            // inquinamento = !risparmio;
                          });
                        },
                      ),
                      const Padding(
                          padding: EdgeInsets.fromLTRB(16.0, 20, 16.0, 0)),
                      Text(
                        'Percorso più breve',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  )),
            ),
            SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 20, 16.0, 0),
                  child: Row(
                    children: [
                      Switch(
                        value: inquinamento,
                        onChanged: (value) {
                          setState(() {
                            inquinamento = value;
                            // risparmio = !inquinamento;
                          });
                        },
                      ),
                      const Padding(
                          padding: EdgeInsets.fromLTRB(16.0, 20, 16.0, 0)),
                      Text(
                        'Minimizza inquinamento',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  )),
            ),
            SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 20, 16.0, 0),
                  child: Column(
                    children: [
                      Text(
                        'Raggio distributori (Km)',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      SizedBox(
                        height: 50,
                        child: Slider(
                          value: raggio.toDouble(),
                          max: 50,
                          min: 5,
                          divisions: 9,
                          label: raggio.round().toString(),
                          onChanged: (value) {
                            setState(() {
                              raggio = value.toInt();
                            });
                          },
                        ),
                      ),
                    ],
                  )),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 20, 16.0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => openFullscreenDialog(
                              context, false, makes, null, setState)
                          .then((value) async {
                        await _loadVeicoli();
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Crea veicolo'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        if (selectedVeicolo == "") {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text("Devi selezionare un veicolo")));
                          return;
                        }
                        await DB.updateSettings({
                          "id": 1,
                          "veicolo": int.parse(selectedVeicolo),
                          "risparmio": risparmio ? 1 : 0,
                          "inquinamento": inquinamento ? 1 : 0,
                          "raggio": raggio
                        });
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text("Impostazioni salvate con successo"),
                                backgroundColor: Colors.lightGreen));
                      },
                      child: const Text('Salva impostazioni'),
                    ),
                    SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        await DB.deleteDatabase();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Impostazioni cancellate"),
                                backgroundColor: Colors.lightGreen));
                        await _loadSettings();
                      },
                      child: const Text('Azzera tutto'),
                    ),
                    SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        // setState(() {
                        //   showTerms = !showTerms;
                        // });
                        _launchUrl(
                            "https://sites.google.com/stud.unive.it/gasmart/home");
                      },
                      child: Text('Termini e condizioni d\'uso',
                          style: TextStyle(
                              fontSize: 14,
                              decoration: TextDecoration.underline)),
                    ),
                    SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        _launchUrl(
                            "https://sites.google.com/stud.unive.it/gasmart/uso");
                      },
                      child: Text('Guida all\'uso',
                          style: TextStyle(
                              fontSize: 14,
                              decoration: TextDecoration.underline)),
                    ),
                    Visibility(
                      visible: showTerms,
                      child: SizedBox(
                        height: 300,
                        width: 300,
                        child: const Markdown(data: '''
**Privacy Policy per GaSmart di Argenta**
**Ultima modifica: 15/01/2024**

Grazie per utilizzare GaSmart, l'applicazione mobile fornita dalla società Argenta ("Noi", "Il nostro" o "Argenta"). Questa Privacy Policy è stata creata per informarti su come raccogliamo, utilizziamo e divulghiamo le informazioni personali degli utenti della nostra App.

-   **Informazioni raccolte**  
    a. **Posizione precisa:** GaSmart raccoglie la posizione precisa dell'utente in modo non continuativo. Questa informazione è fondamentale per fornire servizi specifici all'utente, come la visualizzazione di mappe e la fornitura di dati legati alla posizione.
-   **Utilizzo delle informazioni**  
    a. **Servizi personalizzati:** Utilizziamo la posizione precisa dell'utente per fornire servizi personalizzati, come la visualizzazione di mappe locali legate ai distributori nel raggio indicato.  
    b. **Miglioramento dell'esperienza utente:** L'analisi della posizione ci aiuta a migliorare continuamente l'esperienza dell'utente, ottimizzando la precisione e l'efficacia dei servizi forniti.  
    c. **Condivisione con Google Maps API:** La posizione precisa dell'utente viene condivisa con Google attraverso le API di Google Maps per migliorare la precisione delle informazioni geografiche e offrire una migliore esperienza.
-   **Condivisione di informazioni**  
    a. **Google Maps API:** La posizione precisa dell'utente può essere condivisa con Google attraverso l'utilizzo delle API di Google Maps. Gli utenti sono soggetti alle politiche sulla privacy di Google disponibili all'indirizzo https://policies.google.com/privacy.
-   **Sicurezza**  
    a. **Protezione delle informazioni:** Mettiamo in atto misure di sicurezza ragionevoli per proteggere la posizione precisa dell'utente. Tuttavia, è importante notare che nessun metodo di trasmissione via Internet o di archiviazione elettronica è completamente sicuro.
-   **Modifiche a questa Informativa sulla privacy**  
    a. La presente Informativa sulla privacy potrebbe subire modifiche periodiche. In caso di modifiche significative, pubblicheremo una nuova versione su questa pagina e aggiorneremo la data di "Ultima modifica" in alto.
-   **Contatti**  
    a. Per eventuali domande riguardanti questa Informativa sulla privacy, contattaci all'indirizzo 892604@stud.unive.it.

  

Utilizzando GaSmart, l'utente acconsente alla nostra Informativa sulla privacy e accetta i suoi termini.

Grazie per la fiducia accordata a GaSmart e Argenta.
                    '''),
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

Future<void> openFullscreenDialog(BuildContext context, bool update,
    dynamic makes, Map<String, dynamic>? newV, Function astate) async {
  Map<String, dynamic> x = newV ??
      {
        "marca": "",
        "modello": "",
        "carburante":
            EnumConverter.stringFromTipoCarburante(TipiCarburante.values.first),
        "classe": ClassiVeicolo.values.first
            .toString()
            .replaceAll("ClassiVeicolo.", ""),
        "kmL": 6,
        "anno": DateTime.now().toString(),
        "editable": 1
      };
  TextEditingController textController = TextEditingController();
  TextEditingController makesController = TextEditingController();
  makesController.addListener(() {
    astate(() {
      x["marca"] = makesController.text;
    });
  });
  TextEditingController modelsController = TextEditingController();
  modelsController.addListener(() {
    astate(() {
      x["modello"] = modelsController.text;
    });
  });
  List<String> normalizedMakes = [];
  List<String> normalizedModels = [];
  textController.text = x["kmL"].toString();

  List<String> normalizeDynamic(dynamic obj, String field) {
    List<dynamic> tmp = obj["results"] as List<dynamic>;
    List<String> res = [];
    for (var element in tmp) {
      res.add((element as Map<String, dynamic>)[field] as String);
    }
    return res;
  }

  normalizedMakes = normalizeDynamic(makes, "make");

  Future<String> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.parse(x["anno"].toString()),
        firstDate: DateTime(2015, 8),
        lastDate: DateTime(2101));
    if (picked != null && picked != DateTime.parse(x["anno"].toString())) {
      x["anno"] = picked.toString();
    }
    return picked.toString();
  }

  Future<String> getModels(String make) async {
    final LocalStorage storage = LocalStorage('stor.json');
    try {
      await storage.ready;
      if (storage.getItem(make) != null) {
        return storage.getItem(make) as String;
      }
      var modelsResponse = await http.get(Uri.parse(
          "https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/all-vehicles-model/records?select=model&where=make%3D%27$make%27&group_by=model"));
      await storage.setItem(make, modelsResponse.body);
      return modelsResponse.body;
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Errore inaspettato.')));
    }
    return "";
  }

  Future<int> getMpg(String make, String model) async {
    var modelsResponse = await http.get(Uri.parse(
        "https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/all-vehicles-model/records?select=comb08&where=make%3D%27$make%27%20and%20model%3D%${Uri.encodeComponent(model)}%27"));
    print(
        "https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/all-vehicles-model/records?select=comb08&where=make%3D'$make'%20and%20model%3D%27${Uri.encodeComponent(model)}%27");
    var resp = jsonDecode(modelsResponse.body);
    print(modelsResponse.body);
    // return resp["results"]["0"]["comb08"] as int;
    return 0;
  }

  if (x["modello"] != "" && normalizedModels.isEmpty) {
    var tmp = await getModels(x["marca"] as String);
    astate(() {
      normalizedModels = normalizeDynamic(jsonDecode(tmp), "model");
    });
  }

  // ignore: use_build_context_synchronously
  return showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
            return Dialog.fullscreen(
              child: GestureDetector(
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                },
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Scaffold(
                    appBar: AppBar(
                      title: const Text('Crea veicolo'),
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
                            child: DropdownMenu<String>(
                              width: MediaQuery.of(context).size.width - 32,
                              menuHeight:
                                  MediaQuery.of(context).size.height * 0.6,
                              controller: makesController,
                              inputDecorationTheme:
                                  const InputDecorationTheme(filled: true),
                              initialSelection: x["marca"] as String,
                              onSelected: (value) async {
                                var tmp = await getModels(value as String);
                                setState(() {
                                  normalizedModels = normalizeDynamic(
                                      jsonDecode(tmp), "model");
                                  x["marca"] = value;
                                });
                              },
                              requestFocusOnTap: true,
                              dropdownMenuEntries: normalizedMakes
                                  .map<DropdownMenuEntry<String>>((value) {
                                return DropdownMenuEntry<String>(
                                    value: value, label: value);
                              }).toList(),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Visibility(
                            visible: x["marca"] != "",
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                              child: SizedBox(
                                  child: DropdownMenu<String>(
                                width: MediaQuery.of(context).size.width - 32,
                                menuHeight:
                                    MediaQuery.of(context).size.height * 0.6,
                                controller: modelsController,
                                inputDecorationTheme:
                                    const InputDecorationTheme(filled: true),
                                initialSelection: x["modello"] as String,
                                onSelected: (value) async {
                                  setState(() {
                                    x["modello"] = value;
                                  });
                                },
                                requestFocusOnTap: true,
                                dropdownMenuEntries: normalizedModels
                                    .map<DropdownMenuEntry<String>>((value) {
                                  return DropdownMenuEntry<String>(
                                      value: value, label: value);
                                }).toList(),
                              )),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Visibility(
                            visible: x["marca"] != "",
                            child: Padding(
                                padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                                child: DropdownMenu<String>(
                                  helperText: "Tipo carburante",
                                  width: MediaQuery.of(context).size.width - 40,
                                  inputDecorationTheme:
                                      const InputDecorationTheme(filled: true),
                                  initialSelection: x["carburante"].toString(),
                                  onSelected: (value) => setState(
                                      () => x["carburante"] = value.toString()),
                                  dropdownMenuEntries: TipiCarburante.values
                                      .map((e) => EnumConverter
                                          .stringFromTipoCarburante(e))
                                      .map<DropdownMenuEntry<String>>((value) {
                                    return DropdownMenuEntry<String>(
                                        value: value, label: value);
                                  }).toList(),
                                )),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                            child: TextField(
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly
                              ], // Only numbers can be entered
                              onChanged: (val) => setState(() =>
                                  x["kmL"] = int.parse(textController.text)),
                              controller: textController,
                              decoration: InputDecoration(
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => textController.clear(),
                                ),
                                labelText: 'Consumo (km/L)',
                                filled: true,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Visibility(
                            visible: x["marca"] != "",
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                              child: TextField(
                                  readOnly: true,
                                  controller: TextEditingController(
                                      text:
                                          "${DateTime.parse(x["anno"].toString()).day}/${DateTime.parse(x["anno"].toString()).month}/${DateTime.parse(x["anno"].toString()).year}"),
                                  decoration: InputDecoration(
                                    suffixIcon: IconButton(
                                        icon: const Icon(Icons.calendar_month),
                                        onPressed: () async {
                                          var d = await selectDate(context);
                                          setState(() => x["anno"] = d);
                                        }),
                                    helperText: 'data',
                                    filled: true,
                                  )),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Visibility(
                            visible: x["marca"] != "" && x["modello"] != "",
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FilledButton(
                                    onPressed: () {
                                      if (!update) {
                                        DB.insertVehicleMap(x);
                                      } else {
                                        DB.updateVehicleMap(x);
                                      }
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Salva'),
                                  ),
                                ],
                              ),
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
