import Mixin from '@ember/object/mixin'
// eslint-disable-next-line ember/no-mixins
import ConfirmationMixin from 'ember-onbeforeunload/mixins/confirmation';
import isEqual from 'lodash-es/isEqual';

// eslint-disable-next-line ember/no-new-mixins
export default Mixin.create(ConfirmationMixin, {
  afterModel(model) {
    let record = model
    if(model && !model.serialize && model.record && model.record.serialize) {
      record = model.record;
    }

    if(!record || !record.serialize) {
      // eslint-disable-next-line no-console
      console.error('Confirmation mixin was unable to detect the model');
      return false;
    }

    // Store the full JSON representation of the model after fetching. This is
    // used in isPageDirty() to determine if the model has changed. We can't
    // rely on ember-data's builtin dirty tracking, since it considers all new
    // records dirty and also doesn't currently support nested/embedded models:
    // https://github.com/emberjs/rfcs/pull/21
    record._confirmationRecordInitialSerialized = record.serialize();

    // Determine when the record gets saved, since we don't want to prompt
    // about navigating away if we're in the process of saving the record. This
    // gets set by the Save mixin during saves.
    record._confirmationRecordIsSaved = false;
  },

  isPageDirty(model) {
    let record = model
    if(model && !model.serialize && model.record && model.record.serialize) {
      record = model.record;
    }

    if(!record || !record.serialize) {
      return false;
    }

    let saved = record._confirmationRecordIsSaved;
    if(saved) {
      return false;
    } else {
      let initialSerialized = record._confirmationRecordInitialSerialized;
      let currentSerialized = record.serialize();
      return !isEqual(currentSerialized, initialSerialized);
    }
  },
});
