import classic from 'ember-classic-decorator';

import Form from './form';

@classic
export default class NewRoute extends Form {
  model() {
    this.clearStoreCache();
    return this.fetchModels(this.store.createRecord('admin-group'));
  }
}
