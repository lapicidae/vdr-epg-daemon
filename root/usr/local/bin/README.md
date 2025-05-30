# TVSpielfilm.de EPG Scraper

This Python-based scraper is designed to extract EPG (Electronic Program Guide) data from the mobile website of TVSpielfilm.de and output it in XMLTV or JSON format. It is optimized for integration into systems like VDR (Video Disk Recorder) with the `epgd` daemon, but can also be used as a standalone tool.

## Features

* **Flexible Channel Selection:** Scrapes either all available channels or a specific list of channels provided via the command line or a file.

* **Time Range Scraping:** Supports scraping for a specific start date or for a configurable number of days from the current date.

* **Enhanced Caching:** Utilizes a custom in-memory and file-based caching system to store fetched HTML content and processed JSON data, which significantly reduces the number of live requests and increases scraping speed on repeated runs. Supports cache revalidation, proactive cache cleanup, and cache clearing.

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
* `lxml`
* `cssselect`
* `zlib` (for CRC32 hash comparison in caching)

You can install these using pip:

```bash
pip install requests lxml cssselect
```

### Make Executable

Ensure the script is executable:

```bash
chmod +x tvs-scraper
```

It is recommended to place the script in a directory included in your `PATH` (e.g., `/usr/local/bin/`), or to use the full path to the script.

## Cache Behavior and First Run

The scraper offers a custom caching system to minimize the number of live requests to the server and accelerate execution time on repeated runs. Caching of processed JSON data is **enabled by default**.

**First Run:**
During the **first run** of the scraper, especially when scraping many channels and days, execution can take a **very long time**. This is because the cache is initially empty, and all data must be fetched live from the internet. The default cache Time To Live (`--cache-ttl`) is 6 hours, and the cache is stored by default in the system's temporary directory in a subdirectory named `tvs-cache` (`--cache-dir`).

**Subsequent Runs:**
**After the first run**, subsequent scraper runs will generally be **significantly faster**. The scraper stores fetched HTML responses and processed JSON data on disk. For repeated requests to the same URLs or data, information will be loaded from the cache instead of being downloaded or re-processed, which significantly reduces the time.

**Cache Consistency Check:**
By default, the scraper uses a robust cache consistency check based on `Content-Length` and `CRC32` hashes of content samples from the server. This ensures that cached data is only used if the remote content hasn't changed. A simpler `ETag`/`Last-Modified` based conditional GET can be enabled with `--cache-simple`.

**Proactive Cache Cleanup:**
The scraper now performs proactive cache cleanup to automatically remove stale or no longer relevant cache files (e.g., for past days or data too far in the future). This helps manage cache size and optimize performance. By default, cache files for past days are deleted; this behavior can be disabled with `--cache-keep`.

**Potential Slowdowns due to Cache:**
In certain scenarios, using the cache can, however, lead to **considerable slowdowns**. This can happen if:

* The cache becomes very large (several gigabytes), which slows down read and write operations on the disk.

* The cache storage location (e.g., a slow network drive) is not optimal.

* Many cache entries have expired, and revalidation with the server takes place, which can lead to many live requests despite the cache.

Please note that the cache, depending on the number of channels and days scraped, **can become very large**. Ensure that sufficient disk space is available on the drive where the cache is stored. You can clear the cache at any time using the `--cache-clear` option.

## Usage

The scraper is controlled via the command line with various arguments.

### General Syntax

```bash
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

* `--cache-dir <PATH>`: Specifies a custom directory for cache files. Default is a subdirectory `"tvs-cache"` in the system temporary directory.

* `--cache-clear`: Clears the entire cache directory (including processed data cache) before scraping begins. This will delete all cached responses.

* `--cache-disable`: Disables caching of processed JSON data to disk. Default: `False` (cache is enabled).

* `--cache-ttl <SECONDS>`: Cache Time To Live in seconds. This defines how long a processed JSON file is considered "fresh" and used directly without re-scraping HTML. Default: `6` hours (`21600` seconds).

* `--cache-simple`: If set, enables a simpler conditional GET (using ETag, Last-Modified, and 304 status) for cache consistency. By default, the Content-Length and Range-Request CRC32 comparison method is used.

* `--cache-keep`: If set, cache files for past days will NOT be automatically deleted. By default, past days' cache files are deleted.

* `--max-workers <NUMBER>`: Maximum number of concurrent workers for data fetching. Default: `10`.

* `--max-retries <NUMBER>`: Maximum number of retry attempts for failed HTTP requests (e.g., 429, 5xx, connection errors). Default: `5`.

* `--min-request-delay <SECONDS>`: Minimum delay in seconds between HTTP requests (only for live fetches). Default: `0.05`s.

* `--max-schedule-retries <NUMBER>`: Maximum number of retry attempts for application-level errors during schedule parsing/generation. Default: `3`.

### Examples

**Scrape all channels for today and output XMLTV:**

```bash
./tvs-scraper --output-format xmltv --output-file tvspielfilm.xml --log-level INFO
```

**Scrape specific channels (ARD, ZDF) for the next 3 days and output JSON, with detailed logging:**

```bash
./tvs-scraper --channel-ids "ARD,ZDF" --days 3 --output-format json --output-file my_epg_data.json --verbose
```

**Scrape schedule for a specific day for a channel and clear cache:**

```bash
./tvs-scraper --channel-ids "PRO7" --date 20250601 --cache-clear --output-format xmltv
```

**Use scraper in conjunction with `run-scraper` and syslog:**

By default, the `run-scraper` script logs its output to syslog. To disable this, use `--disable-syslog`.

```bash
/usr/local/bin/run-scraper --syslog-ident my-epg-script
```

(Note that `--use-syslog` and `--syslog-ident` are for the Python scraper itself, while `--disable-syslog` and `--syslog-ident` are for the `run-scraper` script, with the bash script logging to syslog by default.)

## Server Load and Fair Use (max-workers)

The `max-workers` setting directly influences the server load on the `m.tvspielfilm.de` website. Responsible usage is crucial to avoid impairing website availability and to prevent being interpreted as abusive activity (e.g., a denial-of-service-attack).

* **`max-workers`:** This parameter controls the number of concurrent requests your scraper sends to the server.
    * **Low values (e.g., 1-5):** Very gentle on the server, but the scraping process takes longer.
    * **High values (e.g., 10+):** Accelerates the scraping process but can heavily burden the server, especially if it is not designed for many concurrent requests.

* **`--min-request-delay`:** This parameter (default: `0.05` seconds) is often more important than `max-workers` alone. It defines a minimum delay between individual HTTP requests. A delay of 0.5 to 1.0 seconds or more is crucial to avoid overwhelming the server.

**Recommendation for Fair Scraping:**

1.  **Start conservatively:** Always begin with a low number of workers (e.g., 5) and an appropriate `min-request-delay` (e.g., 0.5 seconds).
2.  **Observe server behavior:** Pay attention to error messages like `HTTP Error 429 (Too Many Requests)` or unusually slow response times. These are indicators of overload.
3.  **Adjust parameters:**
    * If you receive errors like 429, increase the `min-request-delay` or reduce `max-workers`.
    * If the scraper runs stably and no issues occur, you can gradually increase `max-workers` or slightly decrease `min-request-delay`, but always with caution.
4.  **Observe `robots.txt`:** Although `m.tvspielfilm.de/robots.txt` does not contain a specific `Crawl-delay` directive, it specifies disallowed paths and explicitly excludes certain bots. Adhere to these rules.
5.  **Utilize caching:** Enabled caching significantly reduces the number of live requests, minimizing server load.

For `m.tvspielfilm.de`, a larger media site, a value of **5 to 10 `max-workers` in combination with a `--min-request-delay` of at least 0.5 seconds** is a fair and appropriate starting point. The default value for `max-workers` is `10`, which provides a good starting point.

## Integration with `epgd` (or similar systems)

The scraper is designed to work with the `epgd` daemon, which typically uses a `channelmap.conf` and an `epgd.conf`. **Note that for integration with `epgd`, the [xmltv-plugin](https://github.com/Zabrimus/epgd-plugin-xmltv) must be installed and activated on your system.**

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

The `epgd.conf` configures the `epgd` daemon itself, including the path to the scraper's output file and the number of days to scrape.

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

* **`EOFError: Ran out of input` or `sqlite3.InterfaceError: bad parameter or other API misuse`:** These errors indicate a corrupted cache entry. Run the scraper with the `--cache-clear` option to clear the cache and re-fetch the data.

  ```bash
  ./tvs-scraper --cache-clear [additional options]
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

* **`fetch_url` Method:** Responsible for fetching URLs and HTTP-level error handling. It now uses `functools.lru_cache` for in-memory caching and implements a custom file-based caching mechanism with content consistency checks, including `Content-Length` and `Range-Request` CRC32 hash comparison, as well as optional ETag/Last-Modified.

* **`_get_channel_list` Method:** Extracts the list of channels and integrates with the file-based cache for channel list data.

* **`_get_schedule_for_channel_and_date` Method:** Extracts program information for a specific channel and day, integrating with the file-based cache for daily schedule data.

* **`parse_detail_page` Method:** Extracts additional details from program detail pages, utilizing `functools.lru_cache` for in-memory caching of detail page content.

* **`_process_channel_day_schedule` Method:** A helper method that orchestrates fetching and parsing for a day and channel, including application-specific retry logic and interaction with the file-based cache.

* **`_proactive_cache_cleanup` Method:** A new method for proactively cleaning up stale or no longer relevant cache files for all channels and dates.

* **`_cleanup_empty_cache_dirs` Method:** A new method for removing empty channel subdirectories within the cache.

* **`generate_xmltv` Function:** Creates the XMLTV output file.

If changes occur on the TVSpielfilm.de website, the CSS selectors in the `TvsLeanScraper` class may need to be updated to find the correct elements.
