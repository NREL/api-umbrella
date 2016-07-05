import Sortable from './sortable';

export default Sortable.extend({
  actions: {
    reorderSubSettings() {
      this.reorderCollection('sub_settings');
    },
  },
});
