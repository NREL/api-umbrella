export function initialize(appInstance) {
  let session = appInstance.lookup('service:session');
  $.ajaxPrefilter(function(options) {
    session.authorize('authorizer:devise-server-side', function(apiKey, adminAuthToken) {
      options.headers = options.headers || {};
      options.headers['X-Api-Key'] = apiKey;
      options.headers['X-Admin-Auth-Token'] = adminAuthToken;
    });
  });
}

export default {
  name: 'jquery-ajax',
  initialize,
};
