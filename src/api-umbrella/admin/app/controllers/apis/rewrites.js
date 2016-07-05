import Sortable from './sortable';

export default Sortable.extend({
  actions: {
    reorderRewrites() {
      this.reorderCollection('rewrites');
    },
  },
});
