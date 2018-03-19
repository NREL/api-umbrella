import { buildValidations, validator } from 'ember-cp-validations';

import DS from 'ember-data';
import I18n from 'npm:i18n-js';
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

export default DS.Model.extend(Validations, {
  name: DS.attr(),
  host: DS.attr(),
  pathPrefix: DS.attr(),
  createdAt: DS.attr(),
  updatedAt: DS.attr(),
  creator: DS.attr(),
  updater: DS.attr(),

  displayName: computed('name', 'host', 'pathPrefix', function() {
    return this.get('name') + ' - ' + this.get('host') + this.get('pathPrefix');
  }),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/api_scopes',
  singlePayloadKey: 'api_scope',
  arrayPayloadKey: 'data',
});
