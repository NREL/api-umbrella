import Model, { attr, belongsTo } from '@ember-data/model';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import classic from 'ember-classic-decorator';
import { buildValidations, validator } from 'ember-cp-validations';

const Validations = buildValidations({
  httpMethod: [
    validator('presence', {
      presence: true,
      description: t('HTTP Method'),
    }),
  ],
  regex: [
    validator('presence', {
      presence: true,
      description: t('Regex'),
    }),
  ],
});

@classic
class SubSettings extends Model.extend(Validations) {
  @attr('number')
  sortOrder;

  @attr()
  httpMethod;

  @attr()
  regex;

  @belongsTo('api/settings', { async: false })
  settings;

  ready() {
    this.setDefaults();
  }

  setDefaults() {
    if(!this.settings) {
      this.set('settings', this.store.createRecord('api/settings'));
    }
  }
}

SubSettings.reopenClass({
  validationClass: Validations,
});

export default SubSettings;
