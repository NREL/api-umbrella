# API Umbrella Router

API Umbrella Router provides the necessary configuration to join together [API Umbrealla Gatekeeper](http://github.com/NREL/api-umbrella-gatekeeper) with other open source proxies. It is part of the [API Umbrella](http://github.com/NREL/api-umbrella) project.

## Overview

The Router's role is to combine API Umbrella Gatekeeper with a load balancer (nginx) and a caching layer (Varnish).

In the API Umbrella stack, the Router is represented by the pieces in caps below:

```
[incoming request] ==> [LOAD BALANCER] ==> [gatekeeper] ==> [CACHE] ==> [LOAD BALANCER] ==> [api backend]
```

## Usage

See [Running API Umbrella]() for setup instructions.

## License

API Umbrella is open sourced under the MIT license.

[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/c8382a3e7e24bd5aeec9b283b4146889 "githalytics.com")](http://githalytics.com/NREL/api-umbrella-router)