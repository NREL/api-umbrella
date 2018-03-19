import Route from '@ember/routing/route';

export default Route.extend({
  renderTemplate() {
    // eslint-disable-next-line no-console
    console.error('Route not found');
    this.render('not-found');
  },
});
