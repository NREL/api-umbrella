# How-to: Configure URL endpoints to an existing web service application

After following the instructions to {file:HowToAddWebService.md define and setup a web service application}, you should have an HAProxy backend configured for your specific web service application. Part of that configuration is creating a routing list file specific to your application. This routing list file determines which URL paths get routed to your web service. Any requests that *begin with* paths found in this routing list file will be routed to your application.

For example, HAProxy was configured to use this routing list file for our SFV web services application: `config/haproxy/routing_matches/api_sfv.lst`. Its contents should look something like this:

    /api/fuel_stations
    /api/transportation_laws

Since the paths given must only match the beginning of the request URL, `/api/fuel_stations/nearest.json` and `/api/transportation_laws/deeply/nested/example.json` would both be routed to the SFV web services application.

To add additional URL paths for your own application, simply edit the specific application's routing matches `.lst` file, and add additional paths on a separate lines. Any requests beginning those paths will be routed to the associated web services application backend.

After making change to this routing list file, you must reload HAProxy:

    sudo /etc/init.d/haproxy reload
