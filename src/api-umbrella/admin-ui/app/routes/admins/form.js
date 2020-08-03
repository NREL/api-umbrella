import Base from './base';
// eslint-disable-next-line ember/no-mixins
import Confirmation from 'api-umbrella-admin-ui/mixins/confirmation';
// eslint-disable-next-line ember/no-mixins
import UncachedModel from 'api-umbrella-admin-ui/mixins/uncached-model';
import { hash } from 'rsvp';

export default Base.extend(Confirmation, UncachedModel, {
  // Return a promise for loading multiple models all together.
  fetchModels(record) {
    return hash({
      record: record,
      groupOptions: this.store.findAll('admin-group', { reload: true }),
    });
  },
});
