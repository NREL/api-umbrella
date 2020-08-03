import Model, { attr, belongsTo } from '@ember-data/model';
import { buildValidations, validator } from 'ember-cp-validations';
import { t } from 'api-umbrella-admin-ui/utils/i18n';

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

export default Model.extend(Validations, {
  sortOrder: attr('number'),
  httpMethod: attr(),
  regex: attr(),

  settings: belongsTo('api/settings', { async: false }),

  ready() {
    this.setDefaults();
    this._super();
  },

  setDefaults() {
    if(!this.settings) {
      this.set('settings', this.store.createRecord('api/settings'));
    }
  },
}).reopenClass({
  validationClass: Validations,
});
