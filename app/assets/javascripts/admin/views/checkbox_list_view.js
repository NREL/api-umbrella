Admin.CheckboxListItemView = Ember.Checkbox.extend({
  checked: function() {
    var checkedValues = this.get('checkedValues') || [];
    var value = this.get('content.id');
    return _.contains(checkedValues, value);
  }.property('content', 'checkedValues.@each'),

  click: function() {
    var checkedValues = this.get('checkedValues') || [];
    var value = this.get('content.id');

    if(this.get('checked')) {
      checkedValues.push(value);
    } else {
      checkedValues = _.without(checkedValues, value);
    }

    checkedValues = _.uniq(checkedValues).sort();
    this.set('checkedValues', checkedValues);
  }
});

Admin.CheckboxListView = Ember.CollectionView.extend({
  itemViewClass: Ember.View.extend({
    checkedValuesBinding: 'parentView.checkedValues',

    template: Ember.Handlebars.compile('<label class="checkbox">{{view Admin.CheckboxListItemView checkedValuesBinding=\'view.checkedValues\' contentBinding=\'view.content\'}} {{view.content.name}}</label>')
  }),
});
