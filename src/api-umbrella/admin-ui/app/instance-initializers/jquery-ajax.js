import $ from 'jquery';

export function initialize(appInstance) {
  const session = appInstance.lookup('service:session');
  $.ajaxPrefilter(function(options) {
    const data = session.get('data.authenticated');
    if(data) {
      options.headers = options.headers || {};

      if(data.api_key) {
        options.headers['X-Api-Key'] = data.api_key;
      }

      if(data.csrf_token) {
        options.headers['X-CSRF-Token'] = data.csrf_token;
      }
    }

    const originalError = options.error;
    options.error = function(xhr, error, code) {
      if(xhr.status === 401) {
        session.invalidate();
      } else if(originalError) {
        originalError.bind(this)(xhr, error, code);
      }
    }
  });
}

export default {
  name: 'jquery-ajax',
  initialize,
};
