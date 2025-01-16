import csv
import urllib.request
from enum import Enum
from math import sqrt, inf, sin, cos, atan2, radians
from maps import GoogleDistanceMatrix, OpenDistanceMatrix
from utils import get_time


class DataType(Enum):
    IMPIANTI = {
        "link": "https://www.mimit.gov.it/images/exportCSV/anagrafica_impianti_attivi.csv",
        "file": "impianti.csv",
        "csv_fields": [
            "idImpianto",
            "Gestore",
            "Bandiera",
            "Tipo Impianto",
            "Nome Impianto",
            "Indirizzo",
            "Comune",
            "Provincia",
            "Latitudine",
            "Longitudine",
        ],
    }
    PREZZO = {
        "link": "https://www.mimit.gov.it/images/exportCSV/prezzo_alle_8.csv",
        "file": "prezzi.csv",
        "csv_fields": ["idImpianto", "descCarburante", "prezzo", "isSelf", "dtComu"],
    }


class Distributori(dict):
    def __init__(self):
        self.last_update = {"date": None, "hour": None}
        self.impianti = []
        self.prezzi = []
        self.open_mat = OpenDistanceMatrix()
        self.g_mat = GoogleDistanceMatrix()
        self.update()

    # Controlla se i file csv sono vecchi
    def __is_outdated(self):
        current_time = get_time()
        return (
            self.last_update["date"] != current_time["date"]
            or int(self.last_update["hour"]) <= 8
        )

    # Se i file sono vecchi li aggiorna
    def __update(self):
        if self.__is_outdated() or len(self.impianti) == 0 or len(self.impianti) == 0:
            print("Updating...", flush=True)
            self.last_update = get_time()

            urllib.request.urlretrieve(
                DataType.PREZZO.value["link"], DataType.PREZZO.value["file"]
            )
            urllib.request.urlretrieve(
                DataType.IMPIANTI.value["link"], DataType.IMPIANTI.value["file"]
            )

            self.prezzi = csv_to_dict(DataType.PREZZO)
            self.impianti = csv_to_dict(DataType.IMPIANTI)

    # Restituisce gli impianti all'interno di un certo raggio dalla posizione passata
    def __get_impianti(self, coord, num, radius):
        if len(coord) != 2:
            return None  # TODO: meglio un'eccezione

        res = []

        for i in self.impianti:
            if get_distance(
                (coord[1], coord[0]), (i["Latitudine"], i["Longitudine"])
            ) <= float(radius):
                print(f"IMPIANTO: {i}", flush=True)
                try:
                    i["Latitudine"] = float(i["Latitudine"])
                    i["Longitudine"] = float(i["Longitudine"])
                    i["Nome"] = i.pop("Nome Impianto")
                    i["Brand"] = i.pop("Gestore")
                except Exception:
                    ...
                res.append(i)
            if len(res) == num:
                break

        return res

    """
    Ritorna gli impianti secondo la distanza reale,
    qua si potrà in caso aggiungere la questione percorso sostenibile
    e robe simili.
    Questa è la funzione che viene chiamata dalla chiamata all'API,
    e poi va a sua volta a chiamare __get_impianti() per fare una scrematura.
    Momentaneamente restituiamo:
    - il percorso più veloce se kml=None
    - il percorso con più conveniente altrimenti, il costo viene calcolato come segue:
        consumo = distanza * kml
        spesa = consumo * prezzo_carburante
    """

    def get(self, api_provider, coord, radius, carburante, num, kml, sorting_key):
        self.__update()
        impianti = self.__get_impianti(coord, num, radius)
        res = []  # impianti che rispettano le nostre condizioni
        res_coords = []  # coordinare degli impianti che rispettano le nostre condizioni

        for i in impianti:
            imp_prices = {}
            comunication_datetime = ""
            for p in self.prezzi:
                if p["idImpianto"] == i["idImpianto"] and int(p["isSelf"]) == 1:
                    imp_prices[p["descCarburante"]] = float(p["prezzo"])
                    if comunication_datetime == "":
                        comunication_datetime = p["dtComu"]
            if carburante in imp_prices:
                res_coords.append([float(i["Longitudine"]), float(i["Latitudine"])])
                i["prezzi"] = imp_prices
                i["TempoComunicazione"] = comunication_datetime
                res.append(i)

        # spesa_consumi: kml, distanze
        # sostenibile: durata
        # distanza: distanze

        if (
            sorting_key == "spesa_consumi" and kml is not None
        ) or sorting_key == "distanza":
            if api_provider == "google":
                mat = self.g_mat.get_distances(coord, res_coords)
            else:
                mat = self.open_mat.get_distances(coord, res_coords)[1:]
        elif sorting_key == "sostenibile":
            if api_provider == "google":
                mat = self.g_mat.get_durations(coord, res_coords)
            else:
                mat = self.open_mat.get_durations(coord, res_coords)[1:]
        else:
            return "Bad format", 400

        idx = 0
        for i in res:
            if sorting_key == "spesa_consumi":
                prezzo = i["prezzi"][carburante]
                i[sorting_key] = (
                    mat[idx] * kml
                ) * prezzo  # è da moltiplicare anche il costo del carburante
            else:
                i[sorting_key] = mat[idx]

            idx += 1

        res = sorted(res, key=lambda k: k[sorting_key])

        return res  # Tanto Flask fa in automatico la conversione in JSON


def csv_to_dict(data_type: DataType):
    res = []

    with open(data_type.value["file"], newline="", encoding="utf8") as csvfile:
        reader = csv.DictReader(
            csvfile,
            fieldnames=data_type.value["csv_fields"],
            delimiter=";",
        )

        next(reader, None)  # Salta data
        next(reader, None)  # Salta nome colonne

        for row in reader:
            res.append(row)

    return res


def get_distance(coord_1, coord_2):
    earth_radius = 6373.0
    distance = inf
    try:  # HACK: Haversine 🦆
        usr_lat = radians(float(coord_1[0]))
        usr_lon = radians(float(coord_1[1]))
        distr_lat = radians(float(coord_2[0]))
        distr_lon = radians(float(coord_2[1]))

        diff_lat = distr_lat - usr_lat
        diff_lon = distr_lon - usr_lon

        a = pow(sin(diff_lat / 2), 2) + cos(usr_lat) * cos(distr_lat) * pow(
            sin(diff_lon / 2), 2
        )
        c = 2 * atan2(sqrt(a), sqrt(1 - a))

        distance = earth_radius * c
    except:
        ...
        # print(
        #     f"Il distributore con Id {row['idImpianto']} ha dei dati mal formati",
        #     flush=True,
        # )
    return distance
