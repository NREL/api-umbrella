import DS from 'ember-data';
import i18n from 'api-umbrella-admin-ui/utils/i18n';
import { validator, buildValidations } from 'ember-cp-validations';

const Validations = buildValidations({
  frontendHost: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      message: i18n.t('must be in the format of "example.com"'),
    }),
  ],
  backendProtocol: validator('presence', true),
  serverHost: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      message: i18n.t('must be in the format of "example.com"'),
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
