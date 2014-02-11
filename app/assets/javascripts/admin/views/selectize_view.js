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
        var values = valueString;
        if(values) {
          values = values.split(',');

          // For new values, ensure the value is an available option in the
          // menu. This is to workaround the fact that we load our valid
          // options on initial load from the global "apiUserExistingRoles"
          // variable. But since new values might be added while operating
          // purely in client-side mode, we need to keep track of any new
          // options that should be available.
          for(var i = 0; i < values.length; i++) {
            var option = {
              id: values[i],
              title: values[i],
            };

            apiUserExistingRoles.push(option);
            this.selectize.addOption(option);
          }

          _.uniq(apiUserExistingRoles);
          this.selectize.refreshOptions(false);
        }

        this.selectize.setValue(values);
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
