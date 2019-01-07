import { buildValidations, validator } from 'ember-cp-validations';

import DS from 'ember-data';
import { computed } from '@ember/object';
import { t } from 'api-umbrella-admin-ui/utils/i18n';

const Validations = buildValidations({
  name: validator('presence', {
    presence: true,
    description: t('Name'),
  }),
  host: [
    validator('presence', {
      presence: true,
      description: t('Host'),
    }),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      description: t('Host'),
      message: t('must be in the format of "example.com"'),
    }),
  ],
  pathPrefix: [
    validator('presence', {
      presence: true,
      description: t('Path Prefix'),
    }),
    validator('format', {
      regex: CommonValidations.url_prefix_format,
      description: t('Path Prefix'),
      message: t('must start with "/"'),
    }),
  ],
});

export default DS.Model.extend(Validations, {
  name: DS.attr(),
  host: DS.attr(),
  pathPrefix: DS.attr(),
  createdAt: DS.attr(),
  updatedAt: DS.attr(),
  creator: DS.attr(),
  updater: DS.attr(),

  displayName: computed('name', 'host', 'pathPrefix', function() {
    return this.name + ' - ' + this.host + this.pathPrefix;
  }),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/api_scopes',
  singlePayloadKey: 'api_scope',
  arrayPayloadKey: 'data',
});
