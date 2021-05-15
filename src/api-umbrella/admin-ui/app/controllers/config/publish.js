import Controller from '@ember/controller';
import { action } from '@ember/object';
import classic from 'ember-classic-decorator';

// eslint-disable-next-line ember/no-classic-classes
@classic
export default class PublishController extends Controller {
  @action
  refreshCurrentRouteController() {
    this.send('refreshCurrentRoute');
  }
}
