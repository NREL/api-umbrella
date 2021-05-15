// eslint-disable-next-line ember/no-mixins
import Confirmation from 'api-umbrella-admin-ui/mixins/confirmation';
// eslint-disable-next-line ember/no-mixins
import UncachedModel from 'api-umbrella-admin-ui/mixins/uncached-model';
import classic from 'ember-classic-decorator';
import { hash } from 'rsvp';

import Base from './base';

@classic
export default class FormRoute extends Base.extend(Confirmation, UncachedModel) {
  // Return a promise for loading multiple models all together.
  fetchModels(record) {
    return hash({
      record: record,
      groupOptions: this.store.findAll('admin-group', { reload: true }),
    });
  }
}
