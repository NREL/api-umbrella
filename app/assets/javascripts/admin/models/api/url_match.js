Admin.ApiUrlMatch = Ember.Model.extend({
  id: Ember.attr(),
  sortOrder: Ember.attr(Number),
  frontendPrefix: Ember.attr(),
  backendPrefix: Ember.attr(),

  backendPrefixWithDefault: function() {
    return this.get('backendPrefix') || this.get('frontendPrefix');
  }.property('backendPrefix', 'frontendPrefix'),
});

Admin.ApiUrlMatch.primaryKey = "id";
Admin.ApiUrlMatch.camelizeKeys = true;
