// eslint-disable-next-line ember/no-mixins
import Confirmation from 'api-umbrella-admin-ui/mixins/confirmation';
import { hash } from 'rsvp';

import Base from './base';

export default class FormRoute extends Base.extend(Confirmation) {
  // Return a promise for loading multiple models all together.
  fetchModels(record) {
    return hash({
      record: record,
      apiScopeOptions: this.store.findAll('api-scope', { reload: true }),
      permissionOptions: this.store.findAll('admin-permission', { reload: true }),
    });
  }
}
