import { computed } from '@ember/object';
import { guidFor } from '@ember/object/internals';
import Mixin from '@ember/object/mixin'
import Sortable from 'sortablejs';
import { t } from 'api-umbrella-admin-ui/utils/i18n';

// eslint-disable-next-line ember/no-new-mixins
export default Mixin.create({
  isReorderable: computed('sortableCollection.length', function() {
    const length = this.sortableCollection.length;
    return (length && length > 1);
  }),

  updateSortOrder(indexes) {
    this.sortableCollection.forEach(function(record) {
      const index = indexes[guidFor(record)];
      record.set('sortOrder', index + 1);
    });
  },

  actions: {
    reorderCollection(containerId) {
      const container = document.getElementById(containerId);
      const buttonText = container.querySelector('.reorder-button-text');

      if(container.classList.contains('reorder-active')) {
        buttonText.innerText = buttonText.dataset.originalText;
        container.classList.remove('reorder-active');
      } else {
        buttonText.dataset.originalText = buttonText.innerText;
        buttonText.innerText = t('Done');
        container.classList.add('reorder-active');
      }

      const tbody = container.querySelector('tbody');
      const sortable = Sortable.create(tbody, {
        handle: '.reorder-handle',
        ghostClass: 'reorder-placeholder',
        animation: 200,
        onUpdate: (event) => {
          const indexes = {};
          const rows = tbody.querySelectorAll('tr');
          for (let i = 0; i < rows.length; i++) {
            const row = rows[i];
            indexes[row.dataset.guid] = i;
          }

          this.updateSortOrder(indexes);
        },
      });
    },
  },
});
