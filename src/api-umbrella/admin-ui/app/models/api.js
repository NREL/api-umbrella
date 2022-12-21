import Model, { attr, belongsTo, hasMany } from '@ember-data/model';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import { init } from 'echarts';
import { buildValidations, validator } from 'ember-cp-validations';

const Validations = buildValidations({
  name: validator('presence', {
    presence: true,
    description: t('Name'),
  }),
  frontendHost: [
    validator('presence', {
      presence: true,
      description: t('Frontend Host'),
    }),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      description: t('Frontend Host'),
      message: t('must be in the format of "example.com"'),
    }),
  ],
  backendHost: [
    validator('presence', {
      presence: true,
      description: t('Frontend Host'),
      disabled: () => {
        return (this.model.frontendHost && this.model.frontendHost[0] === '*');
      },
    }),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      description: t('Backend Host'),
      message: t('must be in the format of "example.com"'),
      disabled: () => {
        return !this.model.backendHost;
      },
    }),
  ],
});

class Api extends Model.extend(Validations) {
  static urlRoot = '/api-umbrella/v1/apis';
  static singlePayloadKey = 'api';
  static arrayPayloadKey = 'data';

  @attr()
  name;

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

  @attr()
  organizationName;

  @attr()
  statusDescription;

  @attr()
  rootApiScope;

  @attr()
  apiScopes;

  @attr()
  adminGroups;

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

  init() {
    super.init(...arguments);

    this.setDefaults();
  }

  setDefaults() {
    if(!this.settings) {
      this.set('settings', this.store.createRecord('api/settings'));
    }
  }

  get exampleIncomingUrlRoot() {
    return 'https://' + (this.frontendHost || '');
  }

  get exampleOutgoingUrlRoot() {
    return this.backendProtocol + '://' + (this.backendHost || this.frontendHost || '');
  }
}

export default Api;
