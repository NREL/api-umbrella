export function initialize(appInstance) {
  let session = appInstance.lookup('service:session');
  $.ajaxPrefilter(function(options) {
    session.authorize('authorizer:devise-server-side', function(apiKey, csrfToken) {
      options.headers = options.headers || {};
      options.headers['X-Api-Key'] = apiKey;
      options.headers['X-CSRF-Token'] = csrfToken;
    });
  });
}

export default {
  name: 'jquery-ajax',
  initialize,
};
