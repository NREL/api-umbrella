import Base from './base';

export default Base.extend({
  downloadUrl: function() {
    return '/admin/stats/users.csv?' + $.param(this.get('query.params'));
  }.property('query.params', 'query.params.query', 'query.params.search', 'query.params.start_at', 'query.params.end_at'),
});
