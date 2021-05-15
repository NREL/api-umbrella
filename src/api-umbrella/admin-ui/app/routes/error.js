import Route from '@ember/routing/route';
import classic from 'ember-classic-decorator';

// eslint-disable-next-line ember/no-classic-classes
@classic
export default class ErrorRoute extends Route {
  renderTemplate() {
    this.render('error');
  }
}
