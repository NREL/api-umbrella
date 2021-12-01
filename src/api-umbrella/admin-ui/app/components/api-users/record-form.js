// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
// eslint-disable-next-line ember/no-mixins
import Save from 'api-umbrella-admin-ui/mixins/save';
import classic from 'ember-classic-decorator';
import I18n from 'i18n-js';
import $ from 'jquery';
import escape from 'lodash-es/escape';

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
    let $key = $(this.element).find('.api-key');
    let $toggle = $(this.element).find('.api-key-reveal-toggle');

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
  submitForm(event) {
    event.preventDefault();
    this.saveRecord({
      element: event.target,
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
