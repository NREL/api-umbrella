// eslint-disable-next-line ember/no-mixins
import Confirmation from 'api-umbrella-admin-ui/mixins/confirmation';
import { hash } from 'rsvp';

import Base from './base';

export default class FormRoute extends Base.extend(Confirmation) {
  // Return a promise for loading multiple models all together.
  fetchModels(record) {
    return hash({
      record: record,
      groupOptions: this.store.findAll('admin-group', { reload: true }),
    });
  }
}
