# GaSmart-server
Tramite il server vengono fornite le API per la richiesta dei distributori.
## Come avviarlo
Per avviare il server utilizzare:
- `make start`, per avviare in modalità normale
- `make debug`, per avviare in modalità debug

## Richiesta
`base_url/get/api/coord/raggio/carb/num_res/kml/sort`
### Parametri
#### Tipo API (`api`)
Per entrambi i tipi è necessario indicare una API key nella rispettiva classe (rispettivamente `GoogleDistanceMatrix` e `OpenDistanceMatrix`).
- `google`, usa le API di Google Maps
- `open`, usa le API di OpenRouteService
#### Coordinate (`coord`)
Le coordinate attuali dell'utente in formato: `latitudine, longitudine`
#### Raggio (`raggio`)
Il raggio entro il quale si devono trovare i distributori rispetto alle coordinate dell'utente.
#### Carburante (`carb`)
Il tipo di carburante dell'utente
#### Numero risultati (`num_res`)
Il numero massimo di distributori che deve contenere la risposta delle API
#### Consumo km/l (`kml`)
Il valore dei consumi km/l del veicolo dell'utente
#### Tipo di sorting dei risultati (`sort`)
- `spesa_consumi`: minimizza il rapporto spesa/consumi
- `distanza`: minimizza la distanza
- `sostenibile`: minimizza i consumi