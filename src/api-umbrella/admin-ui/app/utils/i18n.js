import Jed from 'npm:jed';

var i18n = new Jed({
  locale_data: {
    'api-umbrella': window.localeData,
  },
  domain: 'api-umbrella',
  missing_key_callback: function(key, domain) {
    console.log('Missing translation:', domain, key);
  },
});

export default {
  t(msgid) {
    return i18n.gettext(msgid);
  },
}
