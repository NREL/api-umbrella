import Jed from 'npm:jed';

var i18n = new Jed({
  locale_data: window.localeData,
  domain: 'api-umbrella',
});

function t(msgid) {
  return i18n.gettext(msgid);
}

export { t }
