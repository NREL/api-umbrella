import Ember from 'ember';

export default Ember.View.extend({
  willDestroyElement: function() {
    if(this.apiKeyHideTimeout) {
      clearTimeout(this.apiKeyHideTimeout);
    }
  },

  actions: {
    apiKeyRevealToggle: function() {
      var $key = this.$().find('.api-key');
      var $toggle = this.$().find('.api-key-reveal-toggle');

      if($key.data('revealed') === 'true') {
        $key.text($key.data('api-key-preview'));
        $key.data('revealed', 'false');
        $toggle.text(polyglot.t('admin.reveal_action'));
      } else {
        $key.text($key.data('api-key'));
        $key.data('revealed', 'true');
        $toggle.text(polyglot.t('admin.hide_action'));
      }
    },
  },
});
