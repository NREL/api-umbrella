Admin.StatsLogsRoute = Ember.Route.extend({
  defaultQuery: {
    interval: 'day',
    tz: jstz.determine().name(),
    start: moment().subtract('days', 29).format('YYYY-MM-DD'),
    end: moment().format('YYYY-MM-DD'),
  },

  query: null,

  model: function(params) {
    var query;
    if(params && params.query) {
      query = $.deparam(params.query);
    }

    console.info('set query');
    this.set('query', _.extend({}, this.defaultQuery, query));

    return Admin.Stats.something(this.get('query'));
  },

  setupController: function(controller, model) {
    console.info('setup controller');
    controller.set('query', this.get('query'));
    console.info('MODEL: %o', model);
    controller.set('model', model);
  },

  refresh: function() {
    console.info('refresh!');
  }.observes('query', 'query.search', 'query.interval', 'query.start', 'query.end'),
});
