Admin.ApiServer = Ember.Model.extend({
  _id: Ember.attr(),
  host: Ember.attr(),
  port: Ember.attr(Number),

  hostWithPort: function() {
    var hostWithPort = '';
    return _.compact([this.get('host'), this.get('port')]).join(':');
  }.property('host', 'port'),
});

Admin.ApiServer.primaryKey = "_id";
Admin.ApiServer.camelizeKeys = true;
