import { inject as service } from '@ember/service';
import { clearStoreCache } from 'api-umbrella-admin-ui/utils/uncached-model';

import Form from './form';

export default class EditRoute extends Form {
  @service store;

  model(params) {
    clearStoreCache(this.store);
    return this.store.findRecord('website-backend', params.website_backend_id, { reload: true });
  }
}
