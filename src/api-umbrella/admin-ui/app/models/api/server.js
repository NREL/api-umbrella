import Model, { attr } from '@ember-data/model';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import { buildValidations, validator } from 'ember-cp-validations';
import compact from 'lodash-es/compact';

const Validations = buildValidations({
  host: [
    validator('presence', {
      presence: true,
      description: t('Host'),
    }),
    validator('format', {
      regex: CommonValidations.host_format,
      description: t('Host'),
      message: t('must be in the format of "example.com"'),
    }),
  ],
  port: [
    validator('presence', {
      presence: true,
      description: t('Port'),
    }),
    validator('number', {
      allowString: true,
      description: t('Port'),
    }),
  ],
});

class Server extends Model.extend(Validations) {
  static validationClass = Validations;

  @attr()
  host;

  @attr('number')
  port;

  get hostWithPort() {
    return compact([this.host, this.port]).join(':');
  }
}

export default Server;
