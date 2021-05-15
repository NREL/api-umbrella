import classic from 'ember-classic-decorator';

import Form from './form';

@classic
export default class NewRoute extends Form {
  model() {
    this.clearStoreCache();
    return this.store.createRecord('api-scope');
  }
}
