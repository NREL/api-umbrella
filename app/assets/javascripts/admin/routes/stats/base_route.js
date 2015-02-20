Admin.StatsBaseRoute = Ember.Route.extend({
  defaultQueryParams: {
    tz: jstz.determine().name(),
    search: '',
    start_at: moment().subtract(29, 'days').format('YYYY-MM-DD'),
    end_at: moment().format('YYYY-MM-DD'),
  },

  model: function(params) {
    this.controllerFor('application').set('isLoading', true);

    this.setQueryParams(params);
  },

  setupController: function(controller, model) {
    if(!controller.get('query')) {
      controller.set('query', this.get('query'));
    }

    controller.set('model', model);

    this.controllerFor('application').set('isLoading', false);

    $('ul.nav li').removeClass('active');
    $('ul.nav li.nav-analytics').addClass('active');
  },

  setQueryParams: function(params) {
    var activeQueryParams = {};
    if(params && params.query) {
      activeQueryParams = $.deparam(params.query);
    }

    _.defaults(activeQueryParams, this.defaultQueryParams);
    this.set('activeQueryParams', activeQueryParams);

    var query = this.get('query');
    if(!query) {
      query = Ember.Object.create({ params: {} });
    }

    // Wrap setting the parameters in a begin/end transaction and only set
    // values that differ. This is to cut down on unneeded observer
    // notifications.
    query.beginPropertyChanges();
    for(var prop in activeQueryParams) {
      if(activeQueryParams.hasOwnProperty(prop)) {
        var paramKey = 'params.' + prop;
        var existingValue = query.get(paramKey);
        var newValue = activeQueryParams[prop];

        if(newValue !== existingValue) {
          query.set(paramKey, newValue);
        }
      }
    }
    query.endPropertyChanges();

    if(!this.get('query')) {
      this.set('query', query);
    }
  },

  queryChange: function() {
    var newQueryParams = this.get('query.params');
    if(newQueryParams && !_.isEmpty(newQueryParams)) {
      var activeQueryParams = this.get('activeQueryParams');
      if(!_.isEqual(newQueryParams, activeQueryParams)) {
        this.transitionTo('stats.logs', $.param(newQueryParams));
      }
    }
  }.observes('query.params.query', 'query.params.search', 'query.params.interval', 'query.params.start_at', 'query.params.end_at'),

  actions: {
    error: function() {
      bootbox.alert('An unexpected error occurred. Please check your query and try again.');
    },
  },
});
