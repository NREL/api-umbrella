import classic from 'ember-classic-decorator';

import Form from './form';

@classic
export default class EditRoute extends Form {
  model(params) {
    this.clearStoreCache();
    return this.fetchModels(this.store.findRecord('admin-group', params.admin_group_id, { reload: true }));
  }
}
