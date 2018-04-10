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

      if(data.admin_auth_token) {
        options.headers['X-Admin-Auth-Token'] = data.admin_auth_token;
      }
    }
  });
}

export default {
  name: 'jquery-ajax',
  initialize,
};
