import Base from './base';
import Confirmation from 'api-umbrella-admin-ui/mixins/confirmation';
import UncachedModel from 'api-umbrella-admin-ui/mixins/uncached-model';
import { hash } from 'rsvp';

export default Base.extend(Confirmation, UncachedModel, {
  // Return a promise for loading multiple models all together.
  fetchModels(record) {
    return hash({
      record: record,
      roleOptions: this.get('store').findAll('api-user-role', { reload: true }),
    });
  },
});
