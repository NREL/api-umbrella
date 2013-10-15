Admin.Stats = Ember.Model.extend({
  intervalHits: Ember.attr(),
  totals: Ember.attr(),
  facets: Ember.attr(),
  logs: Ember.attr(),
});

Admin.Stats.reopenClass({
  something: function(params) {
    var record = this.cachedRecordForId(JSON.stringify(params));
    this.adapter.findQuery(this, record, params);
    return record;
  },
});

Admin.Stats.url = "/admin/stats/search";
Admin.Stats.primaryKey = "_id";
Admin.Stats.camelizeKeys = true;
Admin.Stats.adapter = Ember.RESTAdapter.create();
