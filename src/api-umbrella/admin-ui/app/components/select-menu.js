import Ember from 'ember';

export default Ember.Component.extend({
  // If a select menu doesn't have a value set on the model, set it to the
  // value of the first option. This better aligns with the default behavior of
  // select menus (so even if the user doesn't interact with the menu, the
  // model still gets set with the first value that will always be selected).
  //
  // We do this differently than the emberx-select way here:
  // https://github.com/thefrontside/emberx-select/pull/90
  // Instead, we do this with an observer on any value changes. This is needed
  // for select menus inside our modals to work, since the model on those isn't
  // set until the modal opens (so setting a default value just on the initial
  // render doesn't work).
  updateDefault: Ember.on('init', Ember.observer('value', function() {
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
  })),
});
