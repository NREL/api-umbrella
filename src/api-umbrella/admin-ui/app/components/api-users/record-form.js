import classic from 'ember-classic-decorator';
// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
// eslint-disable-next-line ember/no-mixins
import Save from 'api-umbrella-admin-ui/mixins/save';
import I18n from 'i18n-js';
import escape from 'lodash-es/escape';

// eslint-disable-next-line ember/no-classic-classes
@classic
export default class RecordForm extends Component.extend(Save) {
  init() {
    super.init(...arguments);

    this.throttleByIpOptions = [
      { id: false, name: 'Rate limit by API key' },
      { id: true, name: 'Rate limit by IP address' },
    ];

    this.enabledOptions = [
      { id: true, name: 'Enabled' },
      { id: false, name: 'Disabled' },
    ];
  }

  @action
  apiKeyRevealToggle() {
    let $key = this.$().find('.api-key');
    let $toggle = this.$().find('.api-key-reveal-toggle');

    if($key.data('revealed') === 'true') {
      $key.text($key.data('api-key-preview'));
      $key.data('revealed', 'false');
      $toggle.text(I18n.t('admin.reveal_action'));
    } else {
      $key.text($key.data('api-key'));
      $key.data('revealed', 'true');
      $toggle.text(I18n.t('admin.hide_action'));
    }
  }

  @action
  submitForm() {
    this.saveRecord({
      transitionToRoute: 'api_users',
      message(model) {
        let message = 'Successfully saved the user "' + escape(model.get('email')) + '"';
        if(model.get('apiKey')) {
          message += '<br>API Key: <code>' + escape(model.get('apiKey')) + '</code>';
        }

        return message;
      },
    });
  }
}
