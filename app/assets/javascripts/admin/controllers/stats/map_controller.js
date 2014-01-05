Admin.StatsMapController = Admin.StatsBaseController.extend({
  breadcrumbs: function() {
    var crumbs = [];

    var data = this.get('model.map_breadcrumbs');
    for(var i = 0; i < data.length; i++) {
      var crumb = { name: data[i].name };

      if(i < data.length -1) {
        var params = _.clone(this.get('query.params'));
        params.region = data[i].region;
        crumb.linkQuery = $.param(params);
      }

      crumbs.push(crumb);
    }

    return crumbs;
  }.property('model.breadcrumb'),

  downloadUrl: function() {
    return '/admin/stats/map.csv?' + $.param(this.get('query.params'));
  }.property('query.params'),
});

Admin.StatsMapDefaultController = Admin.StatsMapController.extend({
  renderTemplate: function() {
    this.render('stats/users');
  }
});
