Admin.ApisIndexView = Ember.View.extend({
  handleReorderChange: function() {
    var $container = this.$();
    if($container) {
      var $buttonText = this.$().find('.reorder-button-text');
      if(this.get('controller.reorderActive')) {
        $buttonText.data('originalText',  $buttonText.text());
        $buttonText.text('Done');
      } else {
        $buttonText.text($buttonText.data('originalText'));
      }
    }
  }.observes('controller.reorderActive'),
});
