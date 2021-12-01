import Controller from '@ember/controller';
import { action } from '@ember/object';
import { reads } from '@ember/object/computed';
import { inject } from '@ember/service';
import classic from 'ember-classic-decorator';

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
