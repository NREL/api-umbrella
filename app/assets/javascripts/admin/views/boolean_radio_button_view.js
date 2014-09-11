Admin.BooleanRadioButtonView = Ember.View.extend({
  tagName: 'input',
  type: 'radio',
  attributeBindings: ['name', 'type', 'checked:checked:'],

  click: function() {
    this.set('selection', true);

    var otherRadios = $('input[name="' + this.$().attr('name') + '"]').not(this.$());
    _.each(otherRadios, function(radio) {
      var radioView =  Ember.View.views[radio.id];
      if(radioView) {
        radioView.deselect();
      }
    });
  },

  deselect: function() {
    this.set('selection', false);
  },

  checked: function() {
    return !!this.get('selection');
  }.property()
});
