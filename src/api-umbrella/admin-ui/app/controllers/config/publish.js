import Controller from '@ember/controller';
import { action } from '@ember/object';

export default class PublishController extends Controller {
  @action
  refreshCurrentRouteController() {
    this.send('refreshCurrentRoute');
  }
}
