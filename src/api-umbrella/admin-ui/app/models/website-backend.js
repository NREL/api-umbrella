import Model, { attr } from '@ember-data/model';
import { buildValidations, validator } from 'ember-cp-validations';
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

export default Model.extend(Validations, {
  frontendHost: attr(),
  backendProtocol: attr('string', { defaultValue: 'http' }),
  serverHost: attr(),
  serverPort: attr('number', { defaultValue: 80 }),
  createdAt: attr(),
  updatedAt: attr(),
  creator: attr(),
  updater: attr(),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/website_backends',
  singlePayloadKey: 'website_backend',
  arrayPayloadKey: 'data',
});
