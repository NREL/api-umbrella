import Model, { attr } from '@ember-data/model';
import { buildValidations, validator } from 'ember-cp-validations';

import I18n from 'i18n-js';
import { computed } from '@ember/object';

const Validations = buildValidations({
  name: validator('presence', true),
  host: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      message: I18n.t('errors.messages.invalid_host_format'),
    }),
  ],
  pathPrefix: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.url_prefix_format,
      message: I18n.t('errors.messages.invalid_url_prefix_format'),
    }),
  ],
});

export default Model.extend(Validations, {
  name: attr(),
  host: attr(),
  pathPrefix: attr(),
  createdAt: attr(),
  updatedAt: attr(),
  creator: attr(),
  updater: attr(),

  displayName: computed('name', 'host', 'pathPrefix', function() {
    return this.name + ' - ' + this.host + this.pathPrefix;
  }),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/api_scopes',
  singlePayloadKey: 'api_scope',
  arrayPayloadKey: 'data',
});
