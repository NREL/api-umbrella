# import_access_logs

This script can be used to import missing analytics data into Elasticsearch from the nginx access.log files. This may be useful if the normal logging procedures unexpectedly failed (for example, Elasticsearch went offline for longer than rsyslog's buffers allow).

## Caveats

The nginx access.log files only contain very basic information, so the analytics data populated via this script will contain a lot less detail than the normal analytics. This script will restore basic information like the request URL and timestamps for any missing API requests, but more detailed information will be missing. Several notable things that might be missing:

- API key and user information might be missing (if the user passed their API key via the `X-Api-Key` HTTP header).
- IP address geolocation information is not populated.
- API Umbrella's "Denied Code" might not be populated.

## Usage

On any API Umbrella servers running the routing component, first download the contents of this `import_access_logs` directory:

```sh
$ curl -L "https://github.com/NREL/api-umbrella/archive/master.tar.gz" | tar -xz api-umbrella-master/scripts/import_access_logs
$ cd api-umbrella-master/scripts/import_access_logs
```

Pipe any log files into the `import` script:

```sh
$ cat /var/log/api-umbrella/nginx/access.log | ./import
```

This script will attempt to index all requests from the access.log file into Elasticsearch. However, any requests that already exist in Elasticsearch with the same request ID will be skipped, so this should be safe to run on complete access.log files even if part of the data may already exist in Elasticsearch. No duplicate entries will be added and any pre-existing data in Elasticsearch (which is likely more detailed) will be retained.

### Example

Multiple log files can be piped to the import script, and gzipped log files can be piped using `zcat`. Here's an example of how you might run this import script for all of the log files from December 2016 (which would just fill in any missing pieces from the entire month). This may take a while to run, so you may want to run the command in the background on the server (with something like screen) and output to a log file:

```sh
$ zcat /var/log/api-umbrella/nginx/access.log-201612* | ./import &>> import.log
```
