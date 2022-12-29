import Model, { attr } from '@ember-data/model';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import { buildValidations, validator } from 'ember-cp-validations';

const Validations = buildValidations({
  frontendPrefix: [
    validator('presence', {
      presence: true,
      description: t('Frontend Prefix'),
    }),
    validator('format', {
      regex: CommonValidations.url_prefix_format,
      description: t('Frontend Prefix'),
      message: t('must start with "/"'),
    }),
  ],
  backendPrefix: [
    validator('presence', {
      presence: true,
      description: t('Backend Prefix'),
    }),
    validator('format', {
      regex: CommonValidations.url_prefix_format,
      description: t('Backend Prefix'),
      message: t('must start with "/"'),
    }),
  ],
});

class UrlMatch extends Model.extend(Validations) {
  static validationClass = Validations;

  @attr()
  frontendPrefix;

  @attr()
  backendPrefix;

  get backendPrefixWithDefault() {
    return this.backendPrefix || this.frontendPrefix;
  }
}

export default UrlMatch;
