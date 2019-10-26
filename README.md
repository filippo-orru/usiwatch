## Link: ***https://usiwatch.xyz***

# USI-Watch
*USI-Watch ist ein Webtool, das es ermöglicht Kurse aus dem Angebot des USI Graz auszuwählen und dann per Email Benachrichtigungen zu erhalten, wenn Plätze frei werden.*

## Warum? (Motivation)
Der Anreiz dafür war, dass die Online Anmeldung für die beliebten Kurse binnen Minuten vorbei war und man in den Schlangen für die persönliche Anmeldung gut und gerne mehrere Stunden stehen kann. Mit etwas Pech kommt man irgendwann dran und der Kurs ist schon ausgebucht.
Einige melden sich allerdings später ab, z.B. weil sie nicht können oder keine Lust haben. Dadurch wird der Platz frei und, wenn man schnell ist, kann man sich diesen sichern.

Hier kommt USI-Watch ins Spiel. Es wird periodisch die Online-Kursliste des USI Graz überprüft. Wenn ein Platz frei wird, den jemand zu seiner Watchlist hinzugefügt hat, wird er/sie benachrichtigt (sofern die Email Addresse bestätigt wurde).

## Was kann es? (Features)
- Schnelle Kurssuche
- Beispielliste von ausgebuchten Kursen
- Robustes Watchlist System
- Einfacher Login über Emailadresse
- Solides Design auf Desktop und Mobile
- Email double opt-in

## Wie? (Stack)
- Frontend in Elm, Css
- Backend in Flask (Python 3)
- Datenbanksuche mit MongoDB
- Routing mit nginx über Ubuntu-Server
- HTTPS dank letsencrypt

### Fragen (Kontakt)
Am besten über Github Issues, weil ich ungern meine Email hier rein schreiben möchte :)

## Setup (Unix)
Requirements: Python3, tmux, elm executable, 
- `pip install pipenv`
- `git clone https://github.com/ffactory-ofcl/usiwatch.git`
- `cd usiwatch`
- `pipenv install --dev`
- `npm install lightserver --save-dev`
- Adjust run/Flask.sh to point to the correct pipenv python path. Should be similar to mine
- `run/Start.sh`
- Usiwatch should be running at host:port (localhost:8001)