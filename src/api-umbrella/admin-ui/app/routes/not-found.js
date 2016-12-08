import Ember from 'ember';

export default Ember.Route.extend({
  renderTemplate() {
    Ember.Logger.error('Route not found');
    this.render('not-found');
  },
});
