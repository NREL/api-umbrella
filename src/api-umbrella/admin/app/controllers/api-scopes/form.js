import App from '../../app';
import Ember from 'ember';

export default Ember.ObjectController.extend(App.Save, {
  actions: {
    submit: function() {
      this.save({
        transitionToRoute: 'api_scopes',
        message: 'Successfully saved the API scope "' + _.escape(this.get('model.name')) + '"',
      });
    },

    delete: function() {
      bootbox.confirm('Are you sure you want to delete this API scope?', _.bind(function(result) {
        if(result) {
          this.get('model').deleteRecord();
          this.transitionToRoute('api_scopes');
        }
      }, this));
    },
  },
});
