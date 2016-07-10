import Base from './base';

export default Base.extend({
  breadcrumbs: function() {
    let crumbs = [];

    let data = this.get('model.map_breadcrumbs');
    for(let i = 0; i < data.length; i++) {
      let crumb = { name: data[i].name };

      if(i < data.length -1) {
        let params = _.clone(this.get('query.params'));
        params.region = data[i].region;
        crumb.linkQuery = $.param(params);
      }

      crumbs.push(crumb);
    }

    return crumbs;
  }.property('model.breadcrumb'),

  downloadUrl: function() {
    return '/admin/stats/map.csv?' + $.param(this.get('query.params'));
  }.property('query.params', 'query.params.query', 'query.params.search', 'query.params.start_at', 'query.params.end_at', 'query.params.beta_analytics'),
});
