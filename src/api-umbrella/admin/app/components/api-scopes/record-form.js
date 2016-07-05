import Ember from 'ember';
import Save from 'api-umbrella-admin/mixins/save';

export default Ember.Component.extend(Save, {
  actions: {
    submit() {
      this.save({
        transitionToRoute: 'api_scopes',
        message: 'Successfully saved the API scope "' + _.escape(this.get('model.name')) + '"',
      });
    },

    delete() {
      bootbox.confirm('Are you sure you want to delete this API scope?', _.bind(function(result) {
        if(result) {
          this.get('model').deleteRecord();
          this.transitionToRoute('api_scopes');
        }
      }, this));
    },
  },
});
