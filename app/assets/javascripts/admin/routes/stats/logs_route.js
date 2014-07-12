Admin.StatsLogsRoute = Admin.StatsBaseRoute.extend({
  init: function() {
    _.defaults(this.defaultQueryParams, {
      interval: 'day',
    });
  },

  model: function(params) {
    this._super(params);
    if(this.validateOptions()) {
      return Admin.StatsLogs.find(this.get('query.params'));
    } else {
      return {};
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
  }.observes('query.params.search', 'query.params.interval', 'query.params.start', 'query.params.end'),

  validateOptions: function() {
    var valid = true;

    var interval = this.get('query.params.interval');
    var start = moment(this.get('query.params.start'));
    var end = moment(this.get('query.params.end'));

    var range = end.unix() - start.unix();
    switch(interval) {
      case 'minute':
        // 2 days maximum range
        if(range > 2 * 24 * 60 * 60) {
          valid = false;
          bootbox.alert('Your date range is too large for viewing minutely data. Adjust your viewing interval or choose a date range to no more than 2 days.')
        }

        break;
      case 'hour':
        // 31 day maximum range
        if(range > 31 * 24 * 60 * 60) {
          valid = false;
          bootbox.alert('Your date range is too large for viewing hourly data. Adjust your viewing interval or choose a date range to no more than 31 days.')
        }

        break;
    }

    return valid;
  },
});

Admin.StatsLogsDefaultRoute = Admin.StatsLogsRoute.extend({
  renderTemplate: function() {
    this.render('stats/logs', { controller: 'statsLogsDefault' });
  }
});
