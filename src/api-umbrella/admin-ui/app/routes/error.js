import Route from '@ember/routing/route';
import classic from 'ember-classic-decorator';

@classic
export default class ErrorRoute extends Route {
  renderTemplate() {
    this.render('error');
  }
}
