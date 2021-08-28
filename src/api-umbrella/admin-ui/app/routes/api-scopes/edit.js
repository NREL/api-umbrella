import classic from 'ember-classic-decorator';

import Form from './form';

@classic
export default class EditRoute extends Form {
  model(params) {
    this.clearStoreCache();
    return this.store.findRecord('api-scope', params.api_scope_id, { reload: true });
  }
}
