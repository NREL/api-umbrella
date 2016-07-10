import Sortable from './sortable';

export default Sortable.extend({
  actions: {
    reorderUrlMatches() {
      this.reorderCollection('url_matches');
    },
  },
});
