# TVSpielfilm.de EPG Scraper

Dieser Python-basierte Scraper ist darauf ausgelegt, EPG-Daten (Electronic Program Guide) von der mobilen Webseite von TVSpielfilm.de zu extrahieren und sie in einem XMLTV- oder JSON-Format auszugeben. Er ist optimiert für die Integration in Systeme wie VDR (Video Disk Recorder) mit dem `epgd`-Daemon, kann aber auch als eigenständiges Tool verwendet werden.

## Funktionen

* **Flexible Kanalauswahl:** Scrapt entweder alle verfügbaren Kanäle oder eine spezifische Liste von Kanälen, die über die Befehlszeile oder eine Datei angegeben werden.

* **Zeitbereichs-Scraping:** Unterstützt das Scraping für einen bestimmten Starttermin oder für eine konfigurierbare Anzahl von Tagen ab dem aktuellen Datum.

* **Caching:** Nutzt `requests-cache` mit SQLite-Backend, um HTTP-Antworten zwischenzuspeichern, was die Anzahl der Live-Anfragen reduziert und die Scraping-Geschwindigkeit bei wiederholten Läufen erhöht. Unterstützt Cache-Revalidierung und das Löschen des Caches.

* **Parallele Verarbeitung:** Verwendet einen Thread-Pool, um die Sendepläne für Kanäle und Tage gleichzeitig abzurufen, was die Gesamt-Scraping-Zeit erheblich verkürzt.

* **Robuster Retry-Mechanismus:** Implementiert Wiederholungsversuche für Netzwerkfehler (HTTP 429, 5xx, Verbindungsprobleme) sowie für Anwendungsfehler, die während des Parsens des Sendeplans auftreten können.

* **Ausgabeformate:** Generiert EPG-Daten im standardisierten XMLTV-Format (`.xml`) oder als JSON-Array (`.json`).

* **Bild-Validierung:** Optionale Überprüfung der Bild-URLs, um sicherzustellen, dass die Programm-Bilder tatsächlich verfügbar sind.

* **Umfassende Datenextraktion:** Extrahiert detaillierte Programminformationen wie Kurzbeschreibung, Langbeschreibung, Genre, Originaltitel, Land, Jahr, Dauer, FSK, Besetzung, Regisseur, Drehbuch, Kamera, numerische und textuelle Bewertungen sowie IMDb-Bewertungen.

* **XML-Sicherheitsfilter:** Bereinigt alle Textinhalte vor der XMLTV-Ausgabe von ungültigen XML-Zeichen, um die Kompatibilität zu gewährleisten.

* **Syslog-Integration:** Optionale Ausgabe von Log-Nachrichten an Syslog für eine zentrale Protokollierung.

## Installation

### Abhängigkeiten

Der Scraper verwendet hauptsächlich `lxml` für effizientes HTML-Parsing und `cssselect` für die Unterstützung von CSS-Selektoren. Er benötigt die folgenden Python-Bibliotheken:

* `requests`
* `requests-cache`
* `lxml`
* `cssselect`

Sie können diese mit pip installieren:

```
pip install requests requests-cache lxml cssselect

```

### Ausführbar machen

Stellen Sie sicher, dass das Skript ausführbar ist:

```
chmod +x tvs-scraper

```

Es wird empfohlen, das Skript in einem Verzeichnis zu platzieren, das in Ihrem `PATH` enthalten ist (z.B. `/usr/local/bin/`), oder den vollständigen Pfad zum Skript zu verwenden.

### Erster Lauf und Cache-Hinweis

Beim **ersten Durchlauf** des Scrapers, insbesondere wenn viele Kanäle und Tage gescrapt werden, kann die Ausführung **sehr lange dauern**. Dies liegt daran, dass der Cache noch leer ist und alle Daten live aus dem Internet abgerufen werden müssen.

**Nach dem ersten Durchlauf** werden nachfolgende Scraper-Läufe in der Regel **deutlich schneller** sein. Der `requests-cache` speichert die abgerufenen HTTP-Antworten auf der Festplatte. Bei erneuten Anfragen für dieselben URLs werden die Daten aus dem Cache geladen, anstatt sie erneut vom Server herunterzuladen, was die Zeit erheblich verkürzt.

Beachten Sie, dass der Cache, abhängig von der Anzahl der gescrapten Kanäle und Tage, **sehr groß werden kann**. Er kann mehrere Gigabyte an Daten umfassen. Stellen Sie sicher, dass auf dem Laufwerk, auf dem der Cache gespeichert wird (standardmäßig im temporären Systemverzeichnis oder in dem mit `--cache-dir` angegebenen Pfad), ausreichend Speicherplatz vorhanden ist. Sie können den Cache jederzeit mit der Option `--clear-cache` leeren.

## Verwendung

Der Scraper wird über die Kommandozeile mit verschiedenen Argumenten gesteuert.

### Allgemeine Syntax

```
./tvs-scraper [OPTIONEN]

```

### Wichtige Optionen

* `--list-channels`: Listet alle verfügbaren Kanal-IDs und deren Namen auf und beendet das Skript. Nützlich, um die `channelmap.conf` zu konfigurieren.

* `--channel-ids <IDS>`: Eine kommagetrennte Liste von Kanal-IDs (z.B. `"ARD,ZDF"`). Wenn nicht angegeben, werden alle gefundenen Kanäle gescrapt.

* `--channel-ids-file <DATEI>`: Pfad zu einer Datei, die eine kommagetrennte Liste von Kanal-IDs enthält. Überschreibt `--channel-ids`, falls angegeben.

* `--date <DATUM>`: Spezifisches Startdatum für das Scraping im Format `JJJJMMTT` (z.B. `20250523`). Wenn angegeben, wird nur dieser eine Tag gescrapt und `--days` ignoriert.

* `--days <ANZAHL>`: Anzahl der Tage, die gescrapt werden sollen (1-13). Standard: `0` (bedeutet nur heute). Dieses Argument wird ignoriert, wenn `--date` angegeben ist.

* `--output-file <DATEI>`: Pfad zur Ausgabedatei. Die Dateierweiterung (`.json` oder `.xml`) wird automatisch hinzugefügt, falls nicht vorhanden. Standard: `tvspielfilm`.

* `--output-format <FORMAT>`: Ausgabeformat: `"xmltv"` oder `"json"`. Standard: `xmltv`.

* `--img-size <GRÖSSE>`: Bildgröße für die extrahierten URLs (`"300"` oder `"600"`). Standard: `600`.

* `--check-img`: Führt eine zusätzliche HEAD-Anfrage durch, um die Gültigkeit der Bild-URLs zu überprüfen. Erhöht die Scraping-Zeit.

* `--log-level <LEVEL>`: Setzt das Logging-Level (`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`). Standard: `WARNING`.

* `--verbose`: Aktiviert DEBUG-Logging-Ausgabe (überschreibt `--log-level` auf `DEBUG`).

* `--use-syslog`: Sendet Log-Ausgabe an Syslog.

* `--syslog-tag <TAG>`: Bezeichner (Tag) für Syslog-Nachrichten. Standard: `tvs-scraper`.

* `--disable-cache`: Deaktiviert das Caching von HTTP-Antworten. Standardmäßig ist Caching aktiviert.

* `--cache-ttl <SEKUNDEN>`: Cache Time To Live in Sekunden. Standard: 24 Stunden (86400 Sekunden).

* `--cache-dir <PFAD>`: Benutzerdefiniertes Verzeichnis für die Cache-Dateien. Standard ist ein Unterverzeichnis `tvs-cache` im System-Temp-Verzeichnis.

* `--clear-cache`: Löscht das gesamte Cache-Verzeichnis vor dem Start des Scrapers.

* `--keep-stale-cache`: Verhindert, dass abgelaufene Cache-Dateien automatisch entfernt werden.

* `--max-workers <ANZAHL>`: Maximale Anzahl gleichzeitiger Worker für das Abrufen von Daten. Standard: `5`.

* `--max-retries <ANZAHL>`: Maximale Anzahl von Wiederholungsversuchen für fehlgeschlagene HTTP-Anfragen. Standard: `5`.

* `--min-request-delay <SEKUNDEN>`: Minimale Verzögerung in Sekunden zwischen HTTP-Anfragen (nur für Live-Abrufe). Standard: `0.1`.

* `--max-schedule-retries <ANZAHL>`: Maximale Anzahl von Wiederholungsversuchen für Anwendungsfehler während des Parsens/der Generierung des Sendeplans. Standard: `2`.

### Beispiele

**Alle Kanäle für heute scrapen und XMLTV ausgeben:**

```
./tvs-scraper --output-format xmltv --output-file tvspielfilm.xml --log-level INFO

```

**Spezifische Kanäle (ARD, ZDF) für die nächsten 3 Tage scrapen und JSON ausgeben, mit detailliertem Logging:**

```
./tvs-scraper --channel-ids "ARD,ZDF" --days 3 --output-format json --output-file my_epg_data.json --verbose

```

**Sendeplan für einen bestimmten Tag für einen Kanal scrapen und Cache leeren:**

```
./tvs-scraper --channel-ids "PRO7" --date 20250601 --clear-cache --output-format xmltv

```

**Scraper in Verbindung mit `run-scraper` und Syslog verwenden:**

Standardmäßig protokolliert das `run-scraper`-Skript seine Ausgaben an Syslog. Um dies zu deaktivieren, verwenden Sie `--disable-syslog`.

```
/usr/local/bin/run-scraper

```

(Beachten Sie, dass `--use-syslog` und `--syslog-ident` für den Python-Scraper selbst sind, während `--disable-syslog` und `--syslog-ident` für das `run-scraper`-Skript sind, wobei das Bash-Skript standardmäßig an Syslog protokolliert.)

## Integration mit `epgd` (oder ähnlichen Systemen)

Der Scraper ist darauf ausgelegt, mit dem `epgd`-Daemon zu funktionieren, der typischerweise eine `channelmap.conf` und eine `epgd.conf` verwendet.

### `channelmap.conf`

Die `channelmap.conf` definiert, welche Kanäle von welchem EPG-Anbieter gescrapt werden sollen. Für diesen Scraper verwenden Sie das Präfix `xmltv:` gefolgt von der Kanal-ID von TVSpielfilm.de und der `.tvs`-Endung.

**Beispiel-Eintrag in `channelmap.conf`:**

```
xmltv:ARD.tvs:1 = S19.2E-1-1019-10301 // Das Erste HD
xmltv:ZDF.tvs:1 = S19.2E-1-1011-11110 // ZDF HD

```

* `xmltv`: Der Quellenname, der vom `run-scraper`-Skript erkannt wird.

* `ARD.tvs`: Die Kanal-ID von TVSpielfilm.de (`ARD`) mit der Endung `.tvs`.

* `:1`: Optionale `merge`- und `vps`-Parameter für `epgd`.

### `epgd.conf`

Die `epgd.conf` konfiguriert den `epgd`-Daemon selbst, **einschließlich** des Pfads zur Ausgabedatei des Scrapers und der Anzahl der Tage, die gescrapt werden sollen.

**Beispiel-Einträge in `epgd.conf`:**

```
xmltv.input = /epgd/cache/tvs_xmltv.xml
DaysInAdvance = 7
UpdateTime = 24

```

* `xmltv.input`: Der Pfad, unter dem der Scraper die XMLTV-Datei ablegt.

* `DaysInAdvance`: Die Anzahl der Tage, die der Scraper im Voraus scrapen soll.

* `UpdateTime`: Die Zeit in Stunden, nach der die EPG-Daten als veraltet gelten und neu gescrapt werden sollten.

### `run-scraper` Skript

Das bereitgestellte `run-scraper`-Skript automatisiert den Aufruf des Python-Scrapers basierend auf den Einstellungen in `epgd.conf` und `channelmap.conf`. Es prüft, ob ein Update der EPG-Daten notwendig ist (z.B. wenn die Ausgabedatei nicht existiert, zu alt ist oder die `channelmap.conf` neuer ist).

**Wichtige Parameter für `run-scraper`:**

* `--disable-syslog`: Deaktiviert die Syslog-Ausgabe des Bash-Skripts.

* `--syslog-ident <TAG>`: Tag für die Syslog-Nachrichten des Bash-Skripts.

## Fehlerbehebung

* **`EOFError: Ran out of input` oder `sqlite3.InterfaceError: bad parameter or other API misuse`:** Diese Fehler deuten auf einen beschädigten Cache-Eintrag hin. Führen Sie den Scraper mit der Option `--clear-cache` aus, um den Cache zu leeren und die Daten neu abzurufen.

  ```
  ./tvs-scraper --clear-cache [weitere Optionen]
  
  ```

* **Keine Daten extrahiert / Leere Ausgabedatei:**

  * Überprüfen Sie Ihr `--log-level` (verwenden Sie `INFO` oder `DEBUG` für detailliertere Ausgaben).

  * Stellen Sie sicher, dass die angegebenen `--channel-ids` korrekt sind (verwenden Sie `--list-channels` zur Überprüfung).

  * Überprüfen Sie die Internetverbindung und ob TVSpielfilm.de erreichbar ist.

  * Möglicherweise hat sich die HTML-Struktur der Webseite geändert. In diesem Fall müsste der Scraper-Code angepasst werden.

* **`HTTP Error 403 (Forbidden)` oder `429 (Too Many Requests)`:** Dies deutet darauf hin, dass die Webseite Ihre Anfragen blockiert. Der Scraper hat eingebaute Retries und Verzögerungen, aber bei aggressiver Nutzung kann dies weiterhin passieren. Erhöhen Sie den `--min-request-delay` oder reduzieren Sie `--max-workers`.

* **Falsche XMLTV-Ausgabe:** Stellen Sie sicher, dass die `channelmap.conf` korrekt ist und die Kanal-IDs den von TVSpielfilm.de verwendeten IDs entsprechen.

* **Berechtigungsprobleme:** Stellen Sie sicher, dass das Skript und die Ausgabeverzeichnisse die richtigen Lese- und Schreibberechtigungen haben.

## Entwicklung

Der Scraper ist in Python geschrieben und verwendet `requests` für HTTP-Anfragen und `lxml.html` mit `cssselect` für das Parsen von HTML.

* **`TvsLeanScraper` Klasse:** Kapselt die gesamte Scraping-Logik.

* **`fetch_url` Methode:** Verantwortlich für das Abrufen von URLs, Caching und Fehlerbehandlung auf HTTP-Ebene.

* **`parse_sender_list` Methode:** Extrahiert die Liste der Kanäle.

* **`parse_channel_schedule` Methode:** Extrahiert Programminformationen für einen bestimmten Kanal und Tag.

* **`parse_detail_page` Methode:** Extrahiert zusätzliche Details von den Programm-Detailseiten.

* **`_process_channel_day_schedule` Methode:** Eine Hilfsmethode, die den Abruf und das Parsen für einen Tag und Kanal orchestriert, einschließlich der anwendungsspezifischen Retry-Logik.

* **`generate_xmltv` Funktion:** Erstellt die XMLTV-Ausgabedatei.

Bei Änderungen an der TVSpielfilm.de-Webseite müssen möglicherweise die CSS-Selektoren in der `TvsLeanScraper` Klasse aktualisiert werden, um die korrekten Elemente zu finden.
