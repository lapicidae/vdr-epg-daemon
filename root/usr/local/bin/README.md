# TVSpielfilm.de EPG Scraper

This Python-based scraper is designed to extract EPG (Electronic Program Guide) data from the mobile website of TVSpielfilm.de and output it in XMLTV or JSON format. It is optimized for integration into systems like VDR (Video Disk Recorder) with the `epgd` daemon, but can also be used as a standalone tool.

## Features

* **Flexible Channel Selection:** Scrapes either all available channels or a specific list of channels provided via the command line or a file.

* **Time Range Scraping:** Supports scraping for a specific start date or for a configurable number of days from the current date.

* **Caching:** Utilizes `requests-cache` with a SQLite backend to cache HTTP responses, which reduces the number of live requests and increases scraping speed on repeated runs. Supports cache revalidation and cache clearing.

* **Parallel Processing:** Uses a thread pool to concurrently fetch schedules for channels and days, significantly reducing overall scraping time.

* **Robust Retry Mechanism:** Implements retries for network errors (HTTP 429, 5xx, connection issues) as well as for application-level errors that may occur during schedule parsing.

* **Output Formats:** Generates EPG data in the standardized XMLTV format (`.xml`) or as a JSON array (`.json`).

* **Image Validation:** Optional checking of image URLs to ensure that program images are actually available.

* **Comprehensive Data Extraction:** Extracts detailed program information such as short description, long description, genre, original title, country, year, duration, FSK (parental rating), cast, director, screenplay, camera, numerical and textual ratings, and IMDb ratings.

* **XML Security Filter:** Cleanses all text content of invalid XML characters before XMLTV output to ensure compatibility.

* **Syslog Integration:** Optional output of log messages to syslog for centralized logging.

## Installation

### Dependencies

The scraper primarily uses `lxml` for efficient HTML parsing and `cssselect` for CSS selector support. It requires the following Python libraries:

* `requests`
* `requests-cache`
* `lxml`
* `cssselect`

You can install these using pip:

```
pip install requests requests-cache lxml cssselect

```

### Make Executable

Ensure the script is executable:

```
chmod +x tvs-scraper

```

It is recommended to place the script in a directory included in your `PATH` (e.g., `/usr/local/bin/`), or to use the full path to the script.

### First Run and Cache Note

During the **first run** of the scraper, especially when scraping many channels and days, execution can take a **very long time**. This is because the cache is initially empty, and all data must be fetched live from the internet.

**After the first run**, subsequent scraper runs will generally be **significantly faster**. The `requests-cache` stores the fetched HTTP responses on disk. For repeated requests to the same URLs, data will be loaded from the cache instead of being downloaded again from the server, which significantly reduces the time.

Please note that the cache, depending on the number of channels and days scraped, **can become very large**. It may comprise several gigabytes of data. Ensure that sufficient disk space is available on the drive where the cache is stored (by default, in the system's temporary directory or the path specified with `--cache-dir`). You can clear the cache at any time using the `--clear-cache` option.

## Usage

The scraper is controlled via the command line with various arguments.

### General Syntax

```
./tvs-scraper [OPTIONS]

```

### Important Options

* `--list-channels`: Lists all available channel IDs and their names, then exits. Useful for configuring `channelmap.conf`.

* `--channel-ids <IDS>`: A comma-separated list of channel IDs (e.g., `"ARD,ZDF"`). If not provided, all channels are scraped.

* `--channel-ids-file <FILE>`: Path to a file containing a comma-separated list of channel IDs. If provided, this option takes precedence over `--channel-ids`.

* `--date <DATE>`: Specific start date for scraping in `YYYYMMDD` format (e.g., `20250523`). If provided, only this date is scraped, and `--days` is ignored.

* `--days <NUMBER>`: Number of days to scrape (1-13). Default: `0` (means today only). This argument is ignored if `--date` is provided.

* `--output-file <FILE>`: Path to the output file. The file extension (`.json` or `.xml`) will be automatically added if not present. Default: `tvspielfilm`.

* `--output-format <FORMAT>`: Output format: `"xmltv"` or `"json"`. Default: `xmltv`.

* `--img-size <SIZE>`: Image size to extract (`"300"` or `"600"`). Default: `600`.

* `--check-img`: If set, performs an additional HEAD request to check if image URLs are valid. Increases scraping time.

* `--log-level <LEVEL>`: Sets the logging level (`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`). Default: `WARNING`.

* `--verbose`: Enables DEBUG logging output (overrides `--log-level` to `DEBUG`).

* `--use-syslog`: Sends log output to syslog.

* `--syslog-tag <TAG>`: Identifier (tag) to use for syslog messages. Default: `tvs-scraper`.

* `--disable-cache`: Disables caching of HTTP responses to disk. By default, caching is enabled to reduce network requests on repeated runs.

* `--cache-ttl <SECONDS>`: Cache Time To Live in seconds. Default: 24 hours (86400 seconds).

* `--cache-dir <PATH>`: Custom directory for cache files. Default is a subdirectory `tvs-cache` in the system's temporary directory.

* `--clear-cache`: Clears the entire requests-cache directory before starting the scrape. This will delete all cached responses.

* `--keep-stale-cache`: If set, expired cache files will NOT be automatically removed at the start of the run.

* `--max-workers <NUMBER>`: Maximum number of concurrent workers for fetching data. Default: `5`.

* `--max-retries <NUMBER>`: Maximum number of retry attempts for failed HTTP requests. Default: `5`.

* `--min-request-delay <SECONDS>`: Minimum delay in seconds between HTTP requests (only for live fetches). Default: `0.1`.

* `--max-schedule-retries <NUMBER>`: Maximum number of retry attempts for application-level errors during schedule parsing/generation. Default: `2`.

### Examples

**Scrape all channels for today and output XMLTV:**

```
./tvs-scraper --output-format xmltv --output-file tvspielfilm.xml --log-level INFO

```

**Scrape specific channels (ARD, ZDF) for the next 3 days and output JSON, with detailed logging:**

```
./tvs-scraper --channel-ids "ARD,ZDF" --days 3 --output-format json --output-file my_epg_data.json --verbose

```

**Scrape schedule for a specific day for a channel and clear cache:**

```
./tvs-scraper --channel-ids "PRO7" --date 20250601 --clear-cache --output-format xmltv

```

**Use scraper in conjunction with `run-scraper` and syslog:**

By default, the `run-scraper` script logs its output to syslog. To disable this, use `--disable-syslog`.

```
/usr/local/bin/run-scraper

```

(Note that `--use-syslog` and `--syslog-ident` are for the Python scraper itself, while `--disable-syslog` and `--syslog-ident` are for the `run-scraper` script, with the bash script logging to syslog by default.)

## Integration with `epgd` (or similar systems)

The scraper is designed to work with the `epgd` daemon, which typically uses a `channelmap.conf` and an `epgd.conf`.

### `channelmap.conf`

The `channelmap.conf` defines which channels should be scraped by which EPG provider. For this scraper, use the prefix `xmltv:` followed by the TVSpielfilm.de channel ID and the `.tvs` extension.

**Example entry in `channelmap.conf`:**

```
xmltv:ARD.tvs:1 = S19.2E-1-1019-10301 // Das Erste HD
xmltv:ZDF.tvs:1 = S19.2E-1-1011-11110 // ZDF HD

```

* `xmltv`: The source name recognized by the `run-scraper` script.

* `ARD.tvs`: The TVSpielfilm.de channel ID (`ARD`) with the `.tvs` extension.

* `:1`: Optional `merge` and `vps` parameters for `epgd`.

### `epgd.conf`

The `epgd.conf` configures the `epgd` daemon itself, **including** the path to the scraper's output file and the number of days to scrape.

**Example entries in `epgd.conf`:**

```
xmltv.input = /epgd/cache/tvs_xmltv.xml
DaysInAdvance = 7
UpdateTime = 24

```

* `xmltv.input`: The path where the scraper will place the XMLTV file.

* `DaysInAdvance`: The number of days the scraper should scrape in advance.

* `UpdateTime`: The time in hours after which the EPG data is considered stale and should be re-scraped.

### `run-scraper` Script

The provided `run-scraper` script automates the invocation of the Python scraper based on the settings in `epgd.conf` and `channelmap.conf`. It checks if an update of the EPG data is necessary (e.g., if the output file does not exist, is too old, or the `channelmap.conf` is newer).

**Important parameters for `run-scraper`:**

* `--disable-syslog`: Disables the syslog output of the bash script.

* `--syslog-ident <TAG>`: Tag for the syslog messages of the bash script.

## Troubleshooting

* **`EOFError: Ran out of input` or `sqlite3.InterfaceError: bad parameter or other API misuse`:** These errors indicate a corrupted cache entry. Run the scraper with the `--clear-cache` option to clear the cache and re-fetch the data.

  ```
  ./tvs-scraper --clear-cache [additional options]
  
  ```

* **No data extracted / Empty output file:**

  * Check your `--log-level` (use `INFO` or `DEBUG` for more detailed output).

  * Ensure that the specified `--channel-ids` are correct (use `--list-channels` to verify).

  * Check your internet connection and if TVSpielfilm.de is reachable.

  * The HTML structure of the website may have changed. In this case, the scraper code would need to be adapted.

* **`HTTP Error 403 (Forbidden)` or `429 (Too Many Requests)`:** This indicates that the website is blocking your requests. The scraper has built-in retries and delays, but with aggressive use, this can still happen. Increase `--min-request-delay` or reduce `--max-workers`.

* **Incorrect XMLTV output:** Ensure that `channelmap.conf` is correct and that channel IDs match those used by TVSpielfilm.de.

* **Permission issues:** Ensure that the script and output directories have the correct read and write permissions.

## Development

The scraper is written in Python and uses `requests` for HTTP requests and `lxml.html` with `cssselect` for HTML parsing.

* **`TvsLeanScraper` Class:** Encapsulates all scraping logic.

* **`fetch_url` Method:** Responsible for fetching URLs, caching, and HTTP-level error handling.

* **`parse_sender_list` Method:** Extracts the list of channels.

* **`parse_channel_schedule` Method:** Extracts program information for a specific channel and day.

* **`parse_detail_page` Method:** Extracts additional details from program detail pages.

* **`_process_channel_day_schedule` Method:** A helper method that orchestrates fetching and parsing for a day and channel, including application-specific retry logic.

* **`generate_xmltv` Function:** Creates the XMLTV output file.

If changes occur on the TVSpielfilm.de website, the CSS selectors in the `TvsLeanScraper` class may need to be updated to find the correct elements.
