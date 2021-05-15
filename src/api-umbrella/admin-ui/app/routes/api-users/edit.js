import classic from 'ember-classic-decorator';

import Form from './form';

@classic
export default class EditRoute extends Form {
  model(params) {
    this.clearStoreCache();
    return this.fetchModels(this.store.findRecord('api-user', params.api_user_id, { reload: true }));
  }
}
