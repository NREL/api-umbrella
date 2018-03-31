import Base from './base';
import Confirmation from 'api-umbrella-admin-ui/mixins/confirmation';
import UncachedModel from 'api-umbrella-admin-ui/mixins/uncached-model';
import { hash } from 'rsvp';

export default Base.extend(Confirmation, UncachedModel, {
  // Return a promise for loading multiple models all together.
  fetchModels(record) {
    return hash({
      record: record,
      apiScopeOptions: this.get('store').findAll('api-scope', { reload: true }),
      permissionOptions: this.get('store').findAll('admin-permission', { reload: true }),
    });
  },
});
