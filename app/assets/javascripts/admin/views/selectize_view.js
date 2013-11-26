Admin.SelectizeView = Ember.View.extend({
  didInsertElement: function() {
    this.$input = this.$().find('input').selectize({
      plugins: ['restore_on_backspace', 'remove_button'],
      delimiter: ',',
      options: apiUserExistingRoles,
      valueField: 'id',
      labelField: 'title',
      searchField: 'title',
      sortField: 'title',
      onChange: _.bind(this.handleSelectizeChange, this),
      create: true,

      // Add to body so it doesn't get clipped by parent div containers.
      dropdownParent: 'body',
    });

    this.selectize = this.$input[0].selectize;
  },

  // Sync the selectize input with the value binding if the value changes
  // externally.
  valueDidChange: function() {
    if(this.selectize) {
      var valueString = this.get('value');
      if(valueString != this.selectize.getValue()) {
        var value = valueString;
        if(valueString) {
          value = valueString.split(',');
        }

        this.selectize.setValue(value);
      }
    }
  }.observes('value').on('init'),

  // Update the value binding when the selectize input changes.
  handleSelectizeChange: function(value) {
    this.set('value', value);
  },

  willDestroyElement: function() {
    if(this.selectize) {
      this.selectize.destroy();
    }
  },
});
