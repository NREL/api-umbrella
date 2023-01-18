import Model, { attr } from '@ember-data/model';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import { buildValidations, validator } from 'ember-cp-validations';

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

class WebsiteBackend extends Model.extend(Validations) {
  static urlRoot = '/api-umbrella/v1/website_backends';
  static singlePayloadKey = 'website_backend';
  static arrayPayloadKey = 'data';

  @attr()
  frontendHost;

  @attr('string', { defaultValue: 'http' })
  backendProtocol;

  @attr()
  serverHost;

  @attr('number', { defaultValue: 80 })
  serverPort;

  @attr()
  createdAt;

  @attr()
  updatedAt;

  @attr()
  creator;

  @attr()
  updater;
}

export default WebsiteBackend;
