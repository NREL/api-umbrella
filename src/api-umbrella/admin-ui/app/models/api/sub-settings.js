import DS from 'ember-data';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import { validator, buildValidations } from 'ember-cp-validations';

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

export default DS.Model.extend(Validations, {
  sortOrder: DS.attr('number'),
  httpMethod: DS.attr(),
  regex: DS.attr(),

  settings: DS.belongsTo('api/settings', { async: false }),

  ready() {
    this.setDefaults();
    this._super();
  },

  setDefaults() {
    if(!this.get('settings')) {
      this.set('settings', this.get('store').createRecord('api/settings'));
    }
  },
}).reopenClass({
  validationClass: Validations,
});
