import { t } from 'api-umbrella-admin-ui/utils/i18n';

export default function() {
  if(window.apiUmbrellaConfig.web.admin.username_is_email) {
    return t('Email');
  } else {
    return t('Username');
  }
}
