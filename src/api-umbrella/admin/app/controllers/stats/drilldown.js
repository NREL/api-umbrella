import Base from './base';

export default Base.extend({
  breadcrumbs: function() {
    let crumbs = [];

    let data = this.get('model.breadcrumbs');
    for(let i = 0; i < data.length; i++) {
      let crumb = { name: data[i].crumb };

      if(i < data.length -1) {
        let params = _.clone(this.get('query.params'));
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
  }.property('query.params', 'query.params.query', 'query.params.search', 'query.params.start_at', 'query.params.end_at', 'query.params.prefix', 'query.params.beta_analytics'),
});
