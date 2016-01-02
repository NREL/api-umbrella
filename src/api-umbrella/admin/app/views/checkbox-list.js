import Ember from 'ember';

export default Ember.CollectionView.extend({
  itemViewClass: Ember.View.extend({
    checkedValuesBinding: 'parentView.checkedValues',

    template: Ember.Handlebars.compile('<label class="checkbox">{{view Admin.CheckboxListItemView checkedValuesBinding=\'view.checkedValues\' contentBinding=\'view.content\'}} {{view.content.name}}</label>')
  }),
});
