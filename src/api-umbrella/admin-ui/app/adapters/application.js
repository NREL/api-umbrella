import { inject } from '@ember/service';
import RESTAdapter from '@ember-data/adapter/rest';
import classic from 'ember-classic-decorator';
import flatten from 'lodash-es/flatten';
import isArray from 'lodash-es/isArray';
import isPlainObject from 'lodash-es/isPlainObject';
import isString from 'lodash-es/isString';

@classic
export default class Application extends RESTAdapter {
  @inject session;

  get headers() {
    const headers = {};

    const data = this.session?.data?.authenticated;
    if(data) {
      if(data.api_key) {
        headers['X-Api-Key'] = data.api_key;
      }

      if(data.admin_auth_token) {
        headers['X-Admin-Auth-Token'] = data.admin_auth_token;
      }
    }

    return headers;
  }

  // Build the URL using the customizable "urlRoot" attribute that can be set
  // on the model class.
  buildURL(modelName, id, snapshot) {
    if(snapshot && snapshot.type && snapshot.type.urlRoot) {
      let url = snapshot.type.urlRoot;
      if(id) {
        url += '/' + encodeURIComponent(id);
      }

      return url;
    } else {
      return super.buildURL(...arguments);
    }
  }

  // Ember data requires that errors from the API be returned as an array. This
  // normalizes some of our different error responses, so they're always an
  // array.
  handleResponse(status, headers, payload) {
    if(!this.isSuccess(status, headers, payload)) {
      this.normalizePayloadErrors(payload, 'errors');
      this.normalizePayloadErrors(payload, 'error');
    }

    return super.handleResponse(...arguments);
  }

  normalizePayloadErrors(payload, key) {
    if(payload && payload[key]) {
      let rawErrors = payload[key];
      let normalizedErrors = [];

      if(isArray(rawErrors)) {
        // If an array is returned by the API, no need to process further.
        normalizedErrors = rawErrors;
      } else if(isPlainObject(rawErrors)) {
        // Turn an object of error messages into an array of error objects.
        for(let field in rawErrors) {
          // The value might be an array of error messages.
          let messages = flatten([rawErrors[field]]);
          messages.forEach(function(message) {
            normalizedErrors.push({
              field: field,
              message: message,
            });
          });
        }
      } else if(isString(rawErrors)) {
        // Turn a single string error into an array.
        normalizedErrors = [{
          message: rawErrors,
        }];
      } else {
        // If we have some other type of error response, add an "Unexpected
        // error" message.
        normalizedErrors = [{
          message: 'Unexpected error',
        }];
      }

      if(key === 'errors') {
        payload.errors = normalizedErrors;
      } else {
        // When normalizing another key, like "error", append it to any
        // existing items on the expected "errors" attribute.
        let existingErrors = payload.errors || [];
        payload.errors = existingErrors.concat(normalizedErrors);
        delete payload[key];
      }
    }
  }
}
