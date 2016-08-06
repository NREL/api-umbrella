import Ember from 'ember';
import ConfirmationMixin from 'ember-onbeforeunload/mixins/confirmation';

export default Ember.Mixin.create(ConfirmationMixin, {
  afterModel(model) {
    // Store the full JSON representation of the model after fetching. This is
    // used in isPageDirty() to determine if the model has changed. We can't
    // rely on ember-data's builtin dirty tracking, since it considers all new
    // records dirty and also doesn't currently support nested/embedded models:
    // https://github.com/emberjs/rfcs/pull/21
    model.set('_confirmationInitialSerialized', model.serialize());

    // Determine when the record gets saved, since we don't want to prompt
    // about navigating away if we're in the process of saving the record.
    model.set('_confirmationSaved', false);
    model.on('didCreate', function() {
      model.set('_confirmationSaved', true);
    });
    model.on('didUpdate', function() {
      model.set('_confirmationSaved', true);
    });
  },

  isPageDirty(model) {
    if(model) {
      let saved = model.get('_confirmationSaved');
      if(saved) {
        return false;
      } else {
        let initialSerialized = model.get('_confirmationInitialSerialized');
        let currentSerialized = model.serialize();
        return !_.isEqual(currentSerialized, initialSerialized);
      }
    } else {
      return false;
    }
  },
});
