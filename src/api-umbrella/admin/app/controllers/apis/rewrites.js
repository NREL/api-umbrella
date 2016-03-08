import Sortable from './sortable';

export default Sortable.extend({
  actions: {
    reorderRewrites: function() {
      this.reorderCollection('rewrites');
    },
  },
});
