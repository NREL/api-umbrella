import classic from 'ember-classic-decorator';
import { action } from '@ember/object';
import { inject } from '@ember/service';
import { reads } from '@ember/object/computed';
import Controller from '@ember/controller';

// eslint-disable-next-line ember/no-classic-classes
@classic
export default class ApplicationController extends Controller {
  @inject('session')
  session;

  isLoading = null;

  @reads('session.data.authenticated.admin')
  currentAdmin;

  @action
  logout() {
    this.session.invalidate();
  }
}
