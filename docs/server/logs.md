# Log Files

Log files for API Umbrella are stored in `/var/log/api-umbrella/`. Inside that directory you'll find subdirectories for each process API Umbrella runs. Some of the more relevant log files are highlighted below:

- `/var/log/api-umbrella/nginx/access.log`: nginx access for all requests log
- `/var/log/api-umbrella/nginx/current`: nginx error log
- `/var/log/api-umbrella/web-puma/current`: Log file for the Rails web app (providing the admin and APIs)
- `/var/log/api-umbrella/trafficserver/access.blog`: Binary log file for the Traffic Server cache server (use `/opt/api-umbrella/embedded/bin/traffic_logcat` to view)
