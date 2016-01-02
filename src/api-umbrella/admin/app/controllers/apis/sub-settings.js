import Sortable from './sortable';

export default Sortable.extend({
  actions: {
    reorderSubSettings: function() {
      this.reorderCollection('sub_settings');
    },
  },
});
