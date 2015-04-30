'use strict';

var _ = require('lodash'),
    config = require('api-umbrella-config').global(),
    csv = require('csv-string'),
    handlebars = require('handlebars'),
    logger = require('../logger'),
    mime = require('mime'),
    Negotiator = require('negotiator'),
    url = require('url');

exports.errorHandler = function(request, response, error, data) {
  var availableMediaTypes = ['application/json', 'application/xml', 'text/csv', 'text/html'];

  // Prefer the format from the extension given in the URL.
  var urlParts = url.parse(request.url);
  var mimeType = mime.lookup(urlParts.pathname);

  // Fall back to a GET parameter named "format".
  if(mimeType === 'application/octet-stream' && request.query.format) {
    mimeType = mime.lookup(request.query.format.toString());
  }

  // Failing that, use Accept header negotiation.
  if(mimeType === 'application/octet-stream') {
    var negotiator = new Negotiator(request);
    mimeType = negotiator.preferredMediaType(availableMediaTypes);
  }

  if(mimeType === 'application/octet-stream' || availableMediaTypes.indexOf(mimeType) === -1) {
    mimeType = availableMediaTypes[0];
  }

  var format = mime.extension(mimeType);

  var settings;
  if(request.apiUmbrellaGatekeeper && request.apiUmbrellaGatekeeper.settings) {
    settings = request.apiUmbrellaGatekeeper.settings;
  } else {
    settings = config.get('apiSettings');
  }

  // Strip leading and trailing whitespace from template, since it's easy to
  // introduce in multi-line templates and XML doesn't like if there's any
  // leading space before the XML declaration.
  var templateContent = settings.error_templates[format].replace(/^\s+|\s+$/g, '');
  var errorData = settings.error_data[error];
  if(!errorData) {
    errorData = settings.error_data.internal_server_error;
    logger.error({ error_type: error }, 'Error data not found for error type: ' + error);
  }
  data = _.merge({
    baseUrl: request.base,
  }, data || {}, errorData);

  var prop;
  for(prop in data) {
    try {
      // TODO: Templates should be precompiled. Only compile them when the
      // configuration is read-in or changed.
      var valueTemplate = handlebars.compile(data[prop], { noEscape: true });
      data[prop] = valueTemplate(data);
    } catch(e) {
    }
  }

  var statusCode = parseInt(data.status_code, 10);
  if(statusCode === 0) {
    statusCode = 500;
  }

  switch(format) {
  case 'json':
    for(prop in data) {
      data[prop] = JSON.stringify(data[prop]);
    }

    break;
  case 'csv':
    csv.eol = '';
    for(prop in data) {
      data[prop] = csv.stringify(data[prop]);
    }

    break;
  }

  var errorBody;
  try {
    // TODO: Templates should be precompiled. Only compile them when the
    // configuration is read-in or changed.
    var template = handlebars.compile(templateContent, { noEscape: true });
    errorBody = template(data);
  } catch(e) {
  }

  // Allow all errors to be loaded over CORS (in case any underlying APIs are
  // expected to be accessed over CORS then we want to make sure errors are
  // also allowed via CORS).
  response.setHeader('Access-Control-Allow-Origin', '*');

  if(errorBody) {
    if(!response.apiUmbrellaGatekeeper) {
      response.apiUmbrellaGatekeeper = {};
    }

    response.apiUmbrellaGatekeeper.deniedCode = error;

    response.statusCode = statusCode;
    response.setHeader('Content-Type', mimeType);
    response.end(errorBody);
    response.emit('deniedError');
  } else {
    response.statusCode = 500;
    response.setHeader('Content-Type', 'text/plain');
    response.end('Internal Server Error');
    response.emit('deniedError');
  }
};
