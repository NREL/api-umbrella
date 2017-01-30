import Ember from 'ember';
import I18n from 'npm:i18n-js';
import Save from 'api-umbrella-admin-ui/mixins/save';

export default Ember.Component.extend(Save, {
  throttleByIpOptions: [
    { id: false, name: 'Rate limit by API key' },
    { id: true, name: 'Rate limit by IP address' },
  ],

  enabledOptions: [
    { id: true, name: 'Enabled' },
    { id: false, name: 'Disabled' },
  ],

  actions: {
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
    },

    submit() {
      this.saveRecord({
        transitionToRoute: 'api_users',
        message(model) {
          let message = 'Successfully saved the user "' + _.escape(model.get('email')) + '"';
          if(model.get('apiKey')) {
            message += '<br>API Key: <code>' + _.escape(model.get('apiKey')) + '</code>';
          }

          return message;
        },
      });
    },
  },
});
