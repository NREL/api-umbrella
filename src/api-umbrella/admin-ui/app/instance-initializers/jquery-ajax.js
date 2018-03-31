import $ from 'jquery';

export function initialize(appInstance) {
  const session = appInstance.lookup('service:session');
  $.ajaxPrefilter(function(options) {
    const data = session.get('data.authenticated');
    options.headers = options.headers || {};
    options.headers['X-Api-Key'] = data.api_key;
    options.headers['X-Admin-Auth-Token'] = data.admin_auth_token;
  });
}

export default {
  name: 'jquery-ajax',
  initialize,
};
