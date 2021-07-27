import { computed } from '@ember/object';
import Model, { attr } from '@ember-data/model';
import classic from 'ember-classic-decorator';
import { buildValidations, validator } from 'ember-cp-validations';
import I18n from 'i18n-js';
import compact from 'lodash-es/compact';

const Validations = buildValidations({
  host: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.host_format,
      message: I18n.t('errors.messages.invalid_host_format'),
    }),
  ],
  port: [
    validator('presence', true),
    validator('number', { allowString: true }),
  ],
});

@classic
class Server extends Model.extend(Validations) {
  @attr()
  host;

  @attr('number')
  port;

  @computed('host', 'port')
  get hostWithPort() {
    return compact([this.host, this.port]).join(':');
  }
}

Server.reopenClass({
  validationClass: Validations,
});

export default Server;
