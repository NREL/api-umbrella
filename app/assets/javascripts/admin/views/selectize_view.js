Admin.SelectizeView = Ember.View.extend({
  defaultOptions: [],

  didInsertElement: function() {
    this.$input = this.$().find('input').selectize({
      plugins: ['restore_on_backspace', 'remove_button'],
      delimiter: ',',
      options: this.get('defaultOptions'),
      valueField: 'id',
      labelField: 'label',
      searchField: 'label',
      sortField: 'label',
      onChange: _.bind(this.handleSelectizeChange, this),
      create: true,

      // Add to body so it doesn't get clipped by parent div containers.
      dropdownParent: 'body',
    });

    this.selectize = this.$input[0].selectize;
  },

  defaultOptionsDidChange: function() {
    this.set('defaultOptions', this.get('content').map(_.bind(function(item) {
      return {
        id: item.get(this.get('optionValuePath')),
        label: item.get(this.get('optionLabelPath')),
      };
    }, this)));

    if(this.selectize) {
      this.get('defaultOptions').forEach(_.bind(function(option) {
        this.selectize.addOption(option);
      }, this));

      this.selectize.refreshOptions(false);
    }
  }.observes('content.@each').on('init'),

  // Sync the selectize input with the value binding if the value changes
  // externally.
  valueDidChange: function() {
    if(this.selectize) {
      var valueString = this.get('value');
      if(valueString !== this.selectize.getValue()) {
        var values = valueString;
        if(values) {
          values = _.uniq(values.split(','));

          // Ensure the selected value is available as an option in the menu.
          // This takes into account the fact that the default options may not
          // be loaded yet, or they may not contain this specific option.
          for(var i = 0; i < values.length; i++) {
            var option = {
              id: values[i],
              label: values[i],
            };

            this.selectize.addOption(option);
          }

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
