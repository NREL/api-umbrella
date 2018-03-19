import $ from 'jquery';
import AuthenticatedRouteMixin from 'ember-simple-auth/mixins/authenticated-route-mixin';
import Route from '@ember/routing/route';
import moment from 'npm:moment-timezone';

export default Route.extend(AuthenticatedRouteMixin, {
  setupController(controller, model) {
    controller.set('model', model);
    controller.set('dateRanges', this.get('dateRanges'));
    controller.set('presentQueryParamValues', this.get('presentQueryParamValues') || {});
    controller.set('allQueryParamValues', this.get('allQueryParamValues') || {});
    controller.set('backendQueryParamValues', this.get('backendQueryParamValues') || {});

    $('ul.nav li').removeClass('active');
    $('ul.nav li.nav-analytics').addClass('active');
  },

  beforeModel() {
    this._super(...arguments);

    let timezone = this.get('session.data.authenticated.analytics_timezone');
    let dateRanges = {
      'today': {
        label: 'Today',
        start_at: moment().tz(timezone).startOf('day'),
        end_at: moment().tz(timezone).endOf('day'),
      },
      'yesterday': {
        label: 'Yesterday',
        start_at: moment().tz(timezone).subtract(1, 'days'),
        end_at: moment().tz(timezone).subtract(1, 'days').endOf('day'),
      },
      '7d': {
        label: 'Last 7 Days',
        start_at: moment().tz(timezone).subtract(6, 'days'),
        end_at: moment().tz(timezone).endOf('day'),
      },
      '30d': {
        label: 'Last 30 Days',
        start_at: moment().tz(timezone).subtract(29, 'days').startOf('day'),
        end_at: moment().tz(timezone).endOf('day'),
      },
      'this_month': {
        label: 'This Month',
        start_at: moment().tz(timezone).startOf('month'),
        end_at: moment().tz(timezone).endOf('month'),
      },
      'last_month': {
        label: 'Last Month',
        start_at: moment().tz(timezone).subtract(1, 'month').startOf('month'),
        end_at: moment().tz(timezone).subtract(1, 'month').endOf('month'),
      },
    };

    // If this route has the "date_range" query param set (for dynamic date
    // ranges), fill in the "start_at"/"end_at" query params based on the given
    // range. But if "start_at" or "end_at" are set, they take precedent.
    //
    // Most of our other default query params are defined in
    // controllers/stats/base.js, but Ember doesn't support dynamic query
    // params (see https://github.com/emberjs/ember.js/issues/11592), so this
    // is a bit of a workaround. We want dynamic defaults in this case for 2
    // reasons:
    //
    // 1. So that we can define the default after the session data has been
    //    fetched and we know what the default analytics timezone is.
    // 2. So that the default value changes if the user has the app open for
    //    multiple days (we don't want the default value from the very first
    //    load to never be updated again).
    let allParams = _.cloneDeep(this.paramsFor(this.routeName) || {});
    if(allParams.date_range) {
      let range = dateRanges[allParams.date_range];
      if(range) {
        if(!allParams.start_at) {
          allParams.start_at = range.start_at.format('YYYY-MM-DD');
        }
        if(!allParams.end_at) {
          allParams.end_at = range.end_at.format('YYYY-MM-DD');
        }
      }
    }

    this.set('dateRanges', dateRanges);
    this.set('allQueryParamValues', allParams);
    this.set('backendQueryParamValues', _.omit(allParams, ['date_range']));
  },


  validateParams(params) {
    let valid = true;

    let interval = params.interval;
    let start = moment(params.start_at, 'YYYY-MM-DD');
    let end = moment(params.end_at, 'YYYY-MM-DD');

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
      this.set('presentQueryParamValues', present);
    },
  },
});
