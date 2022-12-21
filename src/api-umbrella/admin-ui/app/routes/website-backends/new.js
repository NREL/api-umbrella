import { inject as service } from '@ember/service';
import { clearStoreCache } from 'api-umbrella-admin-ui/utils/uncached-model';

import Form from './form';

export default class NewRoute extends Form {
  @service store;

  model() {
    clearStoreCache(this.store);
    return this.store.createRecord('website-backend', {
      serverPort: 80,
    });
  }
}
