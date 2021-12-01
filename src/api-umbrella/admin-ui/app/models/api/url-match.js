import { or } from '@ember/object/computed';
import Model, { attr } from '@ember-data/model';
import classic from 'ember-classic-decorator';
import { buildValidations, validator } from 'ember-cp-validations';
import I18n from 'i18n-js';

const Validations = buildValidations({
  frontendPrefix: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.url_prefix_format,
      message: I18n.t('errors.messages.invalid_url_prefix_format'),
    }),
  ],
  backendPrefix: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.url_prefix_format,
      message: I18n.t('errors.messages.invalid_url_prefix_format'),
    }),
  ],
});

@classic
class UrlMatch extends Model.extend(Validations) {
  @attr('number')
  sortOrder;

  @attr()
  frontendPrefix;

  @attr()
  backendPrefix;

  @or('backendPrefix', 'frontendPrefix')
  backendPrefixWithDefault;
}

UrlMatch.reopenClass({
  validationClass: Validations,
});

export default UrlMatch;
