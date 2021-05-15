import Route from '@ember/routing/route';
import classic from 'ember-classic-decorator';

// eslint-disable-next-line ember/no-classic-classes
@classic
export default class NotFoundRoute extends Route {
  renderTemplate() {
    // eslint-disable-next-line no-console
    console.error('Route not found');
    this.render('not-found');
  }
}
