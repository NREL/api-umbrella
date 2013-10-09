'use strict';

var clone = require('clone'),
    config = require('../config'),
    csv = require('csv-string'),
    handlebars = require('handlebars'),
    mime = require('mime'),
    Negotiator = require('negotiator'),
    url = require('url');

exports.errorHandler = function(request, response, error) {
  var availableMediaTypes = ['application/json', 'application/xml', 'text/csv', 'text/html'];

  // Prefer the format from the extension given in the URL.
  var urlParts = url.parse(request.url);
  var mimeType = mime.lookup(urlParts.pathname);

  // Fall back to a GET parameter named "format".
  if(mimeType === 'application/octet-stream' && request.query.format) {
    mimeType = mime.lookup(request.query.format);
  }

  // Failing that, use Accept header negotiation.
  if(mimeType === 'application/octet-stream') {
    var negotiator = new Negotiator(request);
    mimeType = negotiator.preferredMediaType(availableMediaTypes);
  }

  if(mimeType === 'application/octet-stream' || availableMediaTypes.indexOf(mimeType) === -1) {
    mimeType = availableMediaTypes[0];
  }

  var extension = mime.extension(mimeType);

  var settings;
  if(request.apiUmbrellaGatekeeper && request.apiUmbrellaGatekeeper.settings) {
    settings = request.apiUmbrellaGatekeeper.settings;
  } else {
    settings = config.get('apiSettings');
  }

  var templateContent = settings.error_templates[extension];
  if(!templateContent) {
    templateContent = settings.error_templates[extension];
  }

  var data = clone(settings.error_data[error]);

  var statusCode = parseInt(data.status_code, 10);
  if(statusCode === 0) {
    statusCode = 500;
  }

  var prop;
  switch(extension) {
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

  var template = handlebars.compile(templateContent, {noEscape: true});

  response.statusCode = statusCode;
  response.setHeader('Content-Type', mimeType);
  response.end(template(data));
};
