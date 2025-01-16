from datetime import datetime
import googlemaps
import openrouteservice
from utils import split_list


class OpenDistanceMatrix(dict):
    def __init__(self):
        self.key = ""
        self.client = openrouteservice.Client(self.key)

    def __get(self, usr_coord, distr_coord):
        coords = [usr_coord] + distr_coord
        print(f"COORDS: {coords}", flush=True)
        res = self.client.distance_matrix(
            locations=coords,
            profile="driving-car",
            metrics=["distance", "duration"],
            validate=False,
        )
        print(f"RES_MAT: {res}", flush=True)
        return res

    # Ritorna quanta distanza bisogna percorrere
    def get_distances(self, usr_coord, distr_coord):
        return self.__get(usr_coord, distr_coord)["distances"][0]

    # Ritorna quanto tempo ci si mette ad arrivare
    def get_durations(self, usr_coord, distr_coord):
        return self.__get(usr_coord, distr_coord)["durations"][0]


class GoogleDistanceMatrix(dict):
    def __init__(self):
        self.key = ""
        self.client = googlemaps.Client(key=self.key)
        self.MAX_DIMENSIONS = 25

    def __get(self, usr_coord, distr_coord):
        u_tmp = usr_coord[0]
        usr_coord[0] = usr_coord[1]
        usr_coord[1] = u_tmp
        usr_coord = tuple(usr_coord)
        for el in distr_coord:
            tmp = distr_coord[distr_coord.index(el)][0]
            distr_coord[distr_coord.index(el)][0] = distr_coord[distr_coord.index(el)][
                1
            ]
            distr_coord[distr_coord.index(el)][1] = tmp
            distr_coord[distr_coord.index(el)] = tuple(el)

        res = []
        dests_lists = list(split_list(distr_coord, self.MAX_DIMENSIONS))

        for dests in dests_lists:
            mat = self.client.distance_matrix(
                origins=usr_coord,
                destinations=dests,
                mode="driving",
                units="metric",
                traffic_model="best_guess",
                departure_time=datetime.now(),
            )
            res += mat["rows"][0]["elements"]
        return res

    def get_distances(self, usr_coord, distr_coord):
        res = []
        for el in self.__get(usr_coord, distr_coord):
            res.append(el["distance"]["value"])
        return res

    def get_durations(self, usr_coord, distr_coord):
        res = []
        for el in self.__get(usr_coord, distr_coord):
            res.append(el["duration"]["value"])
        return res
