import Sortable from './sortable';

export default Sortable.extend({
  actions: {
    reorderUrlMatches: function() {
      this.reorderCollection('url_matches');
    },
  },
});
