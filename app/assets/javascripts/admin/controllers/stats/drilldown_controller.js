Admin.StatsDrilldownController = Admin.StatsBaseController.extend({
  breadcrumbs: function() {
    var crumbs = [];

    var data = this.get('model.metadata.breadcrumbs');
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
  }.property('model.metadata.breadcrumb'),

  downloadUrl: function() {
    return '/admin/stats/map.csv?' + $.param(this.get('query.params'));
  }.property('query.params', 'query.params.search', 'query.params.start', 'query.params.end'),
});

Admin.StatsDrilldownDefaultController = Admin.StatsDrilldownController.extend({
  renderTemplate: function() {
    this.render('stats/drilldown');
  }
});
