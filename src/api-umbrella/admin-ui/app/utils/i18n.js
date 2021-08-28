import Jed from 'jed';

const i18n = new Jed({
  locale_data: window.localeData,
  domain: 'api-umbrella',
});

function t(...args) {
  return i18n.gettext(...args);
}

function sprintf(...args) {
  return Jed.sprintf(...args);
}

export {
  sprintf,
  t,
}
