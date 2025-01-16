import 'dart:convert';
import 'dart:math';

import 'package:GaSmart/models/distributore.dart';
import 'package:GaSmart/models/enums.dart';
import 'package:GaSmart/models/vehicle.dart';
import 'package:GaSmart/utils/db.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:localstorage/localstorage.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  final Function handleScreenChanged;

  const MapScreen(this.handleScreenChanged, {Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final start = TextEditingController();
  final end = TextEditingController();
  bool isVisible = false;
  String api = "api-ip";
  List<LatLng> routpoints = [];
  Position? _currentPosition;
  LatLng _currentLatLng = const LatLng(0, 0);
  List<Distributore> distributori = [];
  String carburante = "Benzina";
  Vehicle? v;
  double raggio = 10;
  bool inquinamento = true;
  String sortOption = "distanza";
  String gapikey = "api-key";

  Widget buildListTile(Distributore d, Function cb) {
    return ListTile(
      title: Text(
        "${d.nome} - ${d.brand}",
        style: TextStyle(color: Theme.of(context).colorScheme.background),
      ),
      subtitle: Text(
        "$carburante €${d.prezzi[carburante]}",
        style: TextStyle(color: Theme.of(context).colorScheme.background),
      ),
      leading: Icon(Icons.account_circle,
          color: Theme.of(context).colorScheme.background),
      trailing: IconButton(
          onPressed: () => cb(),
          icon: Icon(Icons.arrow_right,
              color: Theme.of(context).colorScheme.background)),
    );
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Location services are disabled. Please enable the services')));
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location permissions are permanently denied, we cannot request permissions.')));
      return false;
    }
    return true;
  }

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();

    if (!hasPermission) return;
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((position) {
      setState(() {
        _currentPosition = position;
        _currentLatLng = LatLng(position.latitude, position.longitude);
        _loadSettings();
      });
    }).catchError((dynamic e) {
      debugPrint(e.toString());
    });
  }

  Future<void> _apiCall({String filtro = "distanza"}) async {
    String coordStr =
        "${_currentPosition!.latitude.toStringAsFixed(4)},${_currentPosition!.longitude.toStringAsFixed(4)}";
    print(coordStr);
    String url =
        "$api/get/google/$coordStr/${raggio.toStringAsFixed(0)}/${carburante == "Diesel" ? "Gasolio" : carburante}/25/6/${filtro}";
    url = Uri.encodeFull(url);
    try {
      setState(() {
        isVisible = false;
      });
      LocalStorage storage = LocalStorage('api.json');
      List<dynamic> jsonResp;
      await storage.ready;
      if (storage.getItem(url) != null) {
        jsonResp = jsonDecode(storage.getItem(url) as String);
        print('got from storage');
      } else {
        var response = await http.get(Uri.parse(url),
            headers: {"Keep-Alive": "timeout=15, max=1000"});
        jsonResp = jsonDecode(response.body) as List<dynamic>;
        storage.setItem(url, response.body);
        print('got from api');
      }
      distributori = [];
      for (var dist in jsonResp) {
        try {
          Map<String, double> tmp_prezzi = {};
          (dist["prezzi"] as Map<String, dynamic>).forEach((key, value) {
            String k = "";
            // Supreme Diesel, Hi-Q Diesel, Metano, HiQ Perform+, Blue Super, Blue Diesel
            switch (key) {
              case "Gasolio":
                k = "Diesel";
                break;
              case "Metano":
                k = "GPL";
                break;
              default:
                k = key;
                break;
            }
            tmp_prezzi[k] = dist["prezzi"][key] as double;
          });
          dist["prezzi"] = tmp_prezzi;
          print(dist["prezzi"]);
          if (dist["prezzi"][carburante] != null) {
            distributori.add(Distributore.fromJson(dist));
          }
        } on Exception catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Errore inaspettato.')));
        }
        setState(() {
          isVisible = true;
        });
      }
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Errore inaspettato.')));
    }
  }

  List<LatLng> decodePolyline(String str, int precision) {
    var index = 0,
        lat = 0,
        lng = 0,
        shift = 0,
        result = 0,
        byte = 0x00,
        latitude_change = 0,
        longitude_change = 0,
        factor = pow(10, 5);
    List<LatLng> coordinates = [];

    while (index < str.length) {
      byte = 0x00;
      shift = 0;
      result = 0;

      do {
        byte = str.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      latitude_change = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      shift = result = 0;

      do {
        byte = str.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      longitude_change = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      lat += latitude_change;
      lng += longitude_change;

      coordinates.add(LatLng(lat / factor, lng / factor));
    }

    return coordinates.reversed.toList();
  }

  Future<void> _startNavigation(Distributore d, LatLng p) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Theme.of(context).colorScheme.onBackground,
      content: ListView(
          shrinkWrap: true,
          scrollDirection: Axis.vertical,
          children: [buildListTile(d, () => openMap(d.lat, d.lng))]),
      showCloseIcon: true,
      duration: const Duration(seconds: 50),
    ));

    if (_currentPosition == null) return;
    Location start = Location(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        timestamp: _currentPosition!.timestamp);
    Location end = Location(
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: DateTime.now());

    var v1 = start.latitude;
    var v2 = start.longitude;
    var v3 = end.latitude;
    var v4 = end.longitude;

    try {
      var url = Uri.parse(
          'https://routes.googleapis.com/directions/v2:computeRoutes');
      var response = await http.post(url, body: '''{
  "origin": {
    "location": {
      "latLng": {
        "latitude": $v1,
        "longitude": $v2
      }
    }
  },
  "destination": {
    "location": {
      "latLng": {
        "latitude": $v3,
        "longitude": $v4
      }
    }
  },
  "routeModifiers": {
    "vehicleInfo": {
      "emissionType": "${(carburante == "Diesel" ? "DIESEL" : "GASOLINE")}"
    }
  },
  "travelMode":"DRIVE",
  "routingPreference": "TRAFFIC_AWARE_OPTIMAL",
  "requestedReferenceRoutes": ["FUEL_EFFICIENT"],
  "computeAlternativeRoutes": true,
  "extraComputations": ["FUEL_CONSUMPTION"]
}''', headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": "$gapikey",
        "X-Goog-FieldMask":
            "routes.distanceMeters,routes.duration,routes.routeLabels,routes.routeToken,routes.polyline.encodedPolyline"
      });
      // print(response.body);
      setState(() {
        routpoints = [];
        List<dynamic> routes =
            jsonDecode(response.body)['routes'] as List<dynamic>;
        var rout = routes[0];
        for (var i = 0; i < routes.length; i++) {
          // minimizza inquinamento -> fuel efficient route
          if (inquinamento &&
              (routes[i]['routeLabels'] as List<dynamic>)
                  .contains('FUEL_EFFICIENT')) rout = routes[i];
          // percorso più breve -> default route
          if (!inquinamento &&
              (routes[i]['routeLabels'] as List<dynamic>)
                  .contains('DEFAULT_ROUTE')) rout = routes[i];
        }
        print(rout['routeLabels']);
        routpoints =
            decodePolyline(rout['polyline']['encodedPolyline'] as String, 5);
      });
    } catch (_) {
      print(_);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Errore imprevisto')));
      return;
    }
  }

  double getZoomLevel(double mapLongSidePixel, double km) {
    double ratio = 100;
    double degree = 45;
    double distance;
    km = km * 1000; //Length is in Km
    var k = mapLongSidePixel *
        156543.03392 *
        cos(degree *
            pi /
            180); //k = circumference of the world at the Lat_level, for Z=0
    distance = log((ratio * k) / (km * 100)) / ln2;
    distance = distance - 1; // Z starts from 0 instead of 1
    return (distance);
  }

  Future<void> openMap(double latitude, double longitude) async {
    String googleUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    if (await canLaunchUrl(Uri.parse(googleUrl))) {
      await launchUrl(Uri.parse(googleUrl));
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open maps')));
    }
  }

  Future<void> _loadSettings() async {
    var st = (await DB.getSettings())[0];
    Vehicle? selV;
    try {
      selV = await DB.getVehicle(st["veicolo"] as int);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Inserisci il tuo veicolo per continuare.')));
      return widget.handleScreenChanged(2);
    }
    setState(() {
      v = selV;
      inquinamento = (st["inquinamento"] as int) == 1 ? true : false;
      raggio = (st["raggio"] as int).toDouble();
      carburante = EnumConverter.stringFromTipoCarburante(v!.carburante);
    });
    _apiCall(filtro: "distanza");
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentPosition();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                height: 10,
              ),
              Visibility(
                visible: isVisible,
                replacement: Expanded(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 20,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        CircularProgressIndicator(),
                      ],
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                  ),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    width: MediaQuery.of(context).size.width - 20,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: _currentLatLng,
                        initialZoom: getZoomLevel(
                            MediaQuery.of(context).size.width - 20, raggio),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.gasmart.app',
                        ),
                        PolylineLayer(
                          polylineCulling: false,
                          polylines: [
                            Polyline(
                                points: routpoints,
                                color: Colors.deepPurple,
                                strokeWidth: 9)
                          ],
                        ),
                        MarkerLayer(markers: [
                          Marker(
                              point: _currentLatLng,
                              child: const Icon(Icons.person_pin_circle,
                                  color: Colors.redAccent, size: 45)),
                          ...distributori.map((e) => Marker(
                              point: LatLng(e.lat, e.lng),
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      _startNavigation(e, LatLng(e.lat, e.lng));
                                    },
                                    child: const Icon(Icons.location_on,
                                        color: Colors.redAccent, size: 45),
                                  ),
                                ],
                              )))
                        ])
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet<void>(
                      showDragHandle: true,
                      context: context,
                      backgroundColor:
                          Theme.of(context).colorScheme.onBackground,
                      builder: (context) => StatefulBuilder(
                            builder: (context, setState) {
                              return SizedBox(
                                height: MediaQuery.of(context).size.height,
                                width: MediaQuery.of(context).size.width,
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            DropdownMenu<String>(
                                              leadingIcon: Icon(Icons.sort,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .background),
                                              initialSelection: sortOption,
                                              label: Text("Ordina per",
                                                  style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .background,
                                                      fontSize: 14)),
                                              textStyle: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .background,
                                                  fontSize: 14),
                                              onSelected:
                                                  (String? value) async {
                                                if (value == "distanza") {
                                                  await _apiCall(
                                                      filtro: "distanza");
                                                } else if (value ==
                                                    "sostenibile") {
                                                  await _apiCall(
                                                      filtro: "sostenibile");
                                                  print("sostenibile");
                                                }
                                                // else if (value ==
                                                //     "spesa/consumi") {
                                                //   await _apiCall(
                                                //       filtro: "spesa_consumi");
                                                // }
                                                setState(() {
                                                  sortOption = value!;
                                                  print(sortOption);
                                                  if (value ==
                                                      "prezzo crescente") {
                                                    distributori.sort((a, b) =>
                                                        a.prezzi[carburante]!
                                                            .compareTo(b.prezzi[
                                                                    carburante]
                                                                as num));
                                                  } else if (value ==
                                                      "prezzo decrescente") {
                                                    distributori.sort((a, b) =>
                                                        -(a.prezzi[carburante]!
                                                            .compareTo(b.prezzi[
                                                                    carburante]
                                                                as num)));
                                                  }
                                                });
                                              },
                                              dropdownMenuEntries: [
                                                "prezzo crescente",
                                                "prezzo decrescente",
                                                "distanza",
                                                "sostenibile"
                                              ].map<DropdownMenuEntry<String>>(
                                                  (String value) {
                                                return DropdownMenuEntry<
                                                        String>(
                                                    value: value, label: value);
                                              }).toList(),
                                            )
                                          ],
                                        ),
                                        Visibility(
                                          visible: isVisible,
                                          replacement: Center(
                                              child:
                                                  CircularProgressIndicator()),
                                          child: Expanded(
                                            child: ListView(
                                              shrinkWrap: true,
                                              scrollDirection: Axis.vertical,
                                              children: distributori
                                                  .map((e) =>
                                                      buildListTile(e, () {
                                                        Navigator.pop(context);
                                                        openMap(e.lat, e.lng);
                                                      }))
                                                  .toList(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )),
                              );
                            },
                          ));
                },
                icon: const Icon(Icons.menu),
                label: const Text('Apri lista'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
