import { buildValidations, validator } from 'ember-cp-validations';

import DS from 'ember-data';
import I18n from 'npm:i18n-js';

const Validations = buildValidations({
  frontendHost: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      message: I18n.t('errors.messages.invalid_host_format'),
    }),
  ],
  backendProtocol: validator('presence', true),
  serverHost: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      message: I18n.t('errors.messages.invalid_host_format'),
    }),
  ],
  serverPort: [
    validator('presence', true),
    validator('number', { allowString: true }),
  ],
});

export default DS.Model.extend(Validations, {
  frontendHost: DS.attr(),
  backendProtocol: DS.attr('string', { defaultValue: 'http' }),
  serverHost: DS.attr(),
  serverPort: DS.attr('number', { defaultValue: 80 }),
  createdAt: DS.attr(),
  updatedAt: DS.attr(),
  creator: DS.attr(),
  updater: DS.attr(),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/website_backends',
  singlePayloadKey: 'website_backend',
  arrayPayloadKey: 'data',
});
