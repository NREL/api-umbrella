import Ember from 'ember';
import AuthenticatedRouteMixin from 'ember-simple-auth/mixins/authenticated-route-mixin';

export default Ember.Route.extend(AuthenticatedRouteMixin, {
  setupController(controller, model) {
    controller.set('model', model);
    controller.set('queryParamValues', this.get('queryParamValues') || {});
    controller.set('allQueryParamValues', this.paramsFor(this.routeName));

    $('ul.nav li').removeClass('active');
    $('ul.nav li.nav-analytics').addClass('active');
  },

  validateParams(params) {
    let valid = true;

    let interval = params.interval;
    let start = moment(params.start_at);
    let end = moment(params.end_at);

    let range = end.unix() - start.unix();
    switch(interval) {
      case 'minute':
        // 2 days maximum range
        if(range > 2 * 24 * 60 * 60) {
          valid = false;
          bootbox.alert('Your date range is too large for viewing minutely data. Adjust your viewing interval or choose a date range to no more than 2 days.');
        }

        break;
      case 'hour':
        // 31 day maximum range
        if(range > 31 * 24 * 60 * 60) {
          valid = false;
          bootbox.alert('Your date range is too large for viewing hourly data. Adjust your viewing interval or choose a date range to no more than 31 days.');
        }

        break;
    }

    return valid;
  },

  actions: {
    queryParamsDidChange(changed, present) {
      this._super(...arguments);
      this.set('queryParamValues', present);
    },
  },
});
