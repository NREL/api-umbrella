import Model, { attr, belongsTo } from '@ember-data/model';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import { buildValidations, validator } from 'ember-cp-validations';
import classic from 'ember-classic-decorator';

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
  static validationClass = Validations;

  @attr('number')
  sortOrder;

  @attr()
  httpMethod;

  @attr()
  regex;

  @belongsTo('api/settings', { async: false })
  settings;

  init() {
    super.init(...arguments);

    this.setDefaults();
  }

  setDefaults() {
    if(!this.settings) {
      this.set('settings', this.store.createRecord('api/settings'));
    }
  }
}

export default SubSettings;
