# API Umbrella Web
[![Circle CI](https://circleci.com/gh/NREL/api-umbrella-web.svg?style=svg)](https://circleci.com/gh/NREL/api-umbrella-web)

API Umbrella Web provides the website frontend and web admin tool for the [API Umbrella](http://github.com/NREL/api-umbrella) project. API Umbrella Web is a [Ruby on Rails](http://rubyonrails.org) web application.

Please submit any issues to the [primary API Umbrella issue tracker](https://github.com/NREL/api-umbrella/issues).  

## Usage

To get started, check out the [getting started docs](http://nrel.github.io/api-umbrella/docs/getting-started/).

## Run the tests

### Requirements
 * [Ruby](https://www.ruby-lang.org/en/)
 * [Bundler](http://bundler.io/)
 * [PhantomJS](http://phantomjs.org/download.html)
 * [Docker](https://www.docker.com/) or [MongoDB](https://www.docker.com/) and [Elasticsearch](https://www.elastic.co/products/elasticsearch)


### Commands
```bash
#install dependencies
$ bundle install
# run the DB on the correct ports
$ docker-compose up -d
# run the tests
$ bundle exec rake
```

## Features

*TODO: Finish documenting*

### API Key Signup
Users can sign up for API keys through the front end, by visiting `yourdomain.com/signup`. They will be asked for the following information:

* First name *(required)*
* Last name *(required)*
* email *(required)*
* How will you use the APIs? *(optional)*

Users will also be required to agree with the site *terms & conditions*, as defined to your needs. No default terms and conditions are provided with API Umbrella.

### An API for API Umbrella

### Documentation
Documentation is a work in progress, and can be found in multiple locations:
* [Primary API Umbrella documentation](http://nrel.github.io/api-umbrella/docs/)
* [API Umbrella wiki](https://github.com/NREL/api-umbrella/wiki)

### Admin
The admin section is where you can perform multiple tasks including:
* Configuring APIs
* Viewing analytics
* Setting up users and access control
* Publishing your changes
* Importing and exporting settings

## License

API Umbrella is open sourced under the [MIT license](https://github.com/NREL/api-umbrella-web/blob/master/LICENSE.txt).

## Acknowledgements

Geographic data comes from GeoLite data created by [MaxMind](http://www.maxmind.com).

[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/a0758eb1737f21f4d63eaa487161d8df "githalytics.com")](http://githalytics.com/NREL/api-umbrella-web)
