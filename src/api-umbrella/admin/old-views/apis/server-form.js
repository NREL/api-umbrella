import Ember from 'ember';

export default Ember.View.extend({
  templateName: 'apis/server_form',

  didInsertElement: function() {
    var title = this.get('controller.title');
    if(title) {
      this.set('controller.controllers.modal.title', title);
    }
  }
});
