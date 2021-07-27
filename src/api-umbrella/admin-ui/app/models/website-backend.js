import Model, { attr } from '@ember-data/model';
import classic from 'ember-classic-decorator';
import { buildValidations, validator } from 'ember-cp-validations';
import I18n from 'i18n-js';

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

@classic
class WebsiteBackend extends Model.extend(Validations) {
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

WebsiteBackend.reopenClass({
  urlRoot: '/api-umbrella/v1/website_backends',
  singlePayloadKey: 'website_backend',
  arrayPayloadKey: 'data',
});

export default WebsiteBackend;
