Admin.ApiServer = Ember.Model.extend({
  protocol: Ember.attr(),
  host: Ember.attr(),
  port: Ember.attr(Number),

  urlString: function() {
    return this.get('protocol') + '://' + this.get('host') + ':' + this.get('port');
  }.property('protocol', 'host', 'port'),
});

Admin.ApiServer.primaryKey = "_id";
Admin.ApiServer.camelizeKeys = true;
