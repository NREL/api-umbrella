Admin.ApiUsersEditView = Ember.View.extend({
  // If an admin creates an account, we show the full API key for 10 minutes.
  // Afterwards, we hide the full API key and it is no longer returned. This
  // hides it in the event the window or data stays loaded for that entire
  // time.
  apiKeyHidesAtChanged: function() {
    var apiKeyHidesAt = this.get('controller.model.apiKeyHidesAt');
    if(apiKeyHidesAt) {
      apiKeyHidesAt = moment(apiKeyHidesAt);
      var diff = apiKeyHidesAt.diff(new Date());
      this.apiKeyHideTimeout = setTimeout(_.bind(function() {
        var preview = this.get('controller.model.apiKeyPreview');
        this.$().find('.api-key').text(preview);
        this.$().find('.api-key-hides-at-message').remove();
      }, this), diff);
    }
  }.observes('controller.model.apiKeyHidesAt').on('init'),

  willDestroyElement: function() {
    if(this.apiKeyHideTimeout) {
      clearTimeout(this.apiKeyHideTimeout);
    }
  },
});
