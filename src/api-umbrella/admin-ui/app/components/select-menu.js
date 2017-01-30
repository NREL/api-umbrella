import Ember from 'ember';

export default Ember.Component.extend({
  didRender() {
    this.updateDefault();
  },

  // If a select menu doesn't have a value set on the model, set it to the
  // value of the first option. This better aligns with the default behavior of
  // select menus (so even if the user doesn't interact with the menu, the
  // model still gets set with the first value that will always be selected).
  //
  // We do this differently than the default way emberx-select does it:
  // https://github.com/thefrontside/emberx-select/blob/v3.0.0/addon/components/x-select.js#L207-L212
  // Instead, we do this anytime the select element is rendered (either
  // initially or re-rendered). This is necessary for select menus inside our
  // modals to work, since the select on those isn't set until the modal opens
  // (so setting a default value just on the very first render doesn't work).
  updateDefault() {
    let value = this.get('value');
    if(value === undefined) {
      let options = this.get('options');
      if(options) {
        let firstOption = options[0];
        if(firstOption && firstOption.id) {
          this.sendAction('action', firstOption.id, this);
        }
      }
    }
  },
});
