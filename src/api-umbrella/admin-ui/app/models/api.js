import { computed } from '@ember/object';
import Model, { attr, belongsTo, hasMany } from '@ember-data/model';
import classic from 'ember-classic-decorator';
import { buildValidations, validator } from 'ember-cp-validations';
import I18n from 'i18n-js';

const Validations = buildValidations({
  name: validator('presence', true),
  frontendHost: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      message: I18n.t('errors.messages.invalid_host_format'),
    }),
  ],
  backendHost: [
    validator('presence', {
      presence: true,
      disabled: computed('model.frontendHost', function() {
        return (this.model.frontendHost && this.model.frontendHost[0] === '*');
      }),
    }),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      message: I18n.t('errors.messages.invalid_host_format'),
      disabled: computed.not('model.backendHost'),
    }),
  ],
});

@classic
class Api extends Model.extend(Validations) {
  @attr()
  name;

  @attr('number')
  sortOrder;

  @attr('string', { defaultValue: 'http' })
  backendProtocol;

  @attr()
  frontendHost;

  @attr()
  backendHost;

  @attr('string', { defaultValue: 'least_conn' })
  balanceAlgorithm;

  @attr()
  createdAt;

  @attr()
  updatedAt;

  @attr()
  creator;

  @attr()
  updater;

  @hasMany('api/server', { async: false })
  servers;

  @hasMany('api/url-match', { async: false })
  urlMatches;

  @belongsTo('api/settings', { async: false })
  settings;

  @hasMany('api/sub-settings', { async: false })
  subSettings;

  @hasMany('api/rewrites', { async: false })
  rewrites;

  ready() {
    this.setDefaults();
  }

  setDefaults() {
    if(!this.settings) {
      this.set('settings', this.store.createRecord('api/settings'));
    }
  }

  @computed('frontendHost')
  get exampleIncomingUrlRoot() {
    return 'https://' + (this.frontendHost || '');
  }

  @computed('backendHost', 'backendProtocol', 'fontendHost', 'frontendHost')
  get exampleOutgoingUrlRoot() {
    return this.backendProtocol + '://' + (this.backendHost || this.frontendHost || '');
  }
}

Api.reopenClass({
  urlRoot: '/api-umbrella/v1/apis',
  singlePayloadKey: 'api',
  arrayPayloadKey: 'data',
});

export default Api;
