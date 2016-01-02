Admin.ApisServerFormView = Ember.View.extend({
  templateName: 'apis/server_form',

  didInsertElement: function() {
    var title = this.get('controller.title');
    if(title) {
      this.set('controller.controllers.modal.title', title);
    }
  }
});
