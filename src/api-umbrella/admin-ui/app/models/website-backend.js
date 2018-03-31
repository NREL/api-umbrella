import { buildValidations, validator } from 'ember-cp-validations';

import DS from 'ember-data';
import { t } from 'api-umbrella-admin-ui/utils/i18n';

const Validations = buildValidations({
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
  backendProtocol: validator('presence', {
    presence: true,
    description: t('Backend Protocol'),
  }),
  serverHost: [
    validator('presence', {
      presence: true,
      description: t('Backend Server'),
    }),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      description: t('Backend Server'),
      message: t('must be in the format of "example.com"'),
    }),
  ],
  serverPort: [
    validator('presence', {
      presence: true,
      description: t('Backend Port'),
    }),
    validator('number', {
      allowString: true,
      description: t('Backend Port'),
    }),
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
