Admin.StatsDrilldownController = Admin.StatsBaseController.extend({
  breadcrumbs: function() {
    var crumbs = [];

    var data = this.get('model.breadcrumbs');
    for(var i = 0; i < data.length; i++) {
      var crumb = { name: data[i].crumb };

      if(i < data.length -1) {
        var params = _.clone(this.get('query.params'));
        params.prefix = data[i].prefix;
        crumb.linkQuery = $.param(params);
      }

      crumbs.push(crumb);
    }

    if(crumbs.length <= 1) {
      crumbs = [];
    }

    return crumbs;
  }.property('model.breadcrumbs'),

  downloadUrl: function() {
    return '/api-umbrella/v1/analytics/drilldown.csv?' + $.param(this.get('query.params')) + '&api_key=' + webAdminAjaxApiKey;
  }.property('query.params', 'query.params.query', 'query.params.search', 'query.params.start_at', 'query.params.end_at', 'query.params.prefix'),
});

Admin.StatsDrilldownDefaultController = Admin.StatsDrilldownController.extend({
  renderTemplate: function() {
    this.render('stats/drilldown');
  }
});
