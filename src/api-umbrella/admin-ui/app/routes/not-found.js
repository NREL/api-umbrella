import Route from '@ember/routing/route';
import classic from 'ember-classic-decorator';

@classic
export default class NotFoundRoute extends Route {
  renderTemplate() {
    // eslint-disable-next-line no-console
    console.error('Route not found');
    this.render('not-found');
  }
}
