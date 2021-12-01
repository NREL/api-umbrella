import 'daterangepicker';

// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import { inject } from '@ember/service';
import { tagName } from '@ember-decorators/component';
import { observes } from '@ember-decorators/object';
import classic from 'ember-classic-decorator';
import I18n from 'i18n-js';
import $ from 'jquery';
import QueryBuilder from 'jQuery-QueryBuilder';
import forEach from 'lodash-es/forEach';
import moment from 'moment-timezone';

QueryBuilder.define('filter-description', function() {
  this.on('afterUpdateRuleFilter afterUpdateRuleOperator', function(e, rule) {
    let $b = rule.$el.find('button.filter-description');
    const description = e.builder.getFilterDescription(rule.filter, rule);

    if(!description) {
      $b.hide();
    } else {
      if($b.length === 0) {
        $b = $('<button type="button" class="btn btn-sm btn-info filter-description btn-tooltip tooltip-trigger"><i class="fas fa-question-circle"></i></button>');
        $b.prependTo(rule.$el.find(QueryBuilder.selectors.rule_actions));
      } else {
        $b.css('display', '');
      }

      $b.attr('data-tippy-content', description);
    }
  });
});

@classic
@tagName("")
export default class QueryForm extends Component {
  @inject('session')
  session;

  enableInterval = false;

  @action
  didInsert() {
    let rangeOptions = {};
    let rangeKeys = {};
    forEach(this.dateRanges, function(range, key) {
      rangeOptions[range.label] = [
        range.start_at,
        range.end_at,
      ];
      rangeKeys[range.label] = key;
    });
    this.set('rangeOptions', rangeOptions);
    this.set('rangeKeys', rangeKeys);

    let $dateRangePicker = $('#reportrange');
    $dateRangePicker.daterangepicker({
      ranges: rangeOptions,
      showDropdowns: true,
      minYear: 2000,
      maxYear: new Date().getFullYear() + 1,
    });
    $dateRangePicker.on('showCalendar.daterangepicker', this.handleDateRangeCalendarShow.bind(this));
    $dateRangePicker.on('hideCalendar.daterangepicker', this.handleDateRangeCalendarHide.bind(this));
    $dateRangePicker.on('apply.daterangepicker', this.handleDateRangeApply.bind(this));

    this.dateRangePicker = $dateRangePicker.data('daterangepicker');
    this.updateDateRange();

    let stringOperators = [
      'begins_with',
      'not_begins_with',
      'equal',
      'not_equal',
      'contains',
      'not_contains',
      'is_null',
      'is_not_null',
    ];

    let selectOperators = [
      'equal',
      'not_equal',
      'is_null',
      'is_not_null',
    ];

    let numberOperators = [
      'equal',
      'not_equal',
      'less',
      'less_or_equal',
      'greater',
      'greater_or_equal',
      'between',
      'is_null',
      'is_not_null',
    ];

    let $queryBuilder = $('#query_builder').queryBuilder({
      plugins: {
        'filter-description': {
          mode: 'tippy',
        },
      },
      allow_empty: true,
      allow_groups: false,
      filters: [
        {
          id: 'request_method',
          label: I18n.t('admin.stats.fields.request_method.label'),
          description: I18n.t('admin.stats.fields.request_method.description_markdown'),
          type: 'string',
          operators: selectOperators,
          input: 'select',
          values: {
            'get': 'GET',
            'post': 'POST',
            'put': 'PUT',
            'delete': 'DELETE',
            'head': 'HEAD',
            'patch': 'PATCH',
            'options': 'OPTIONS',
          },
        },
        {
          id: 'request_scheme',
          label: I18n.t('admin.stats.fields.request_scheme.label'),
          description: I18n.t('admin.stats.fields.request_scheme.description_markdown'),
          type: 'string',
          operators: selectOperators,
          input: 'select',
          values: {
            'http': 'http',
            'https': 'https',
          },
        },
        {
          id: 'request_host',
          label: I18n.t('admin.stats.fields.request_host.label'),
          description: I18n.t('admin.stats.fields.request_host.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_path',
          label: I18n.t('admin.stats.fields.request_path.label'),
          description: I18n.t('admin.stats.fields.request_path.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_url_query',
          label: I18n.t('admin.stats.fields.request_url_query.label'),
          description: I18n.t('admin.stats.fields.request_url_query.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        ...((this.session.data.authenticated.elasticsearch_template_version < 2) ? [{
          id: 'request_url',
          label: I18n.t('admin.stats.fields.request_url.label'),
          description: I18n.t('admin.stats.fields.request_url.description_markdown'),
          type: 'string',
          operators: stringOperators,
        }] : []),
        {
          id: 'request_ip',
          label: I18n.t('admin.stats.fields.request_ip.label'),
          description: I18n.t('admin.stats.fields.request_ip.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_ip_country',
          label: I18n.t('admin.stats.fields.request_ip_country.label'),
          description: I18n.t('admin.stats.fields.request_ip_country.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_ip_region',
          label: I18n.t('admin.stats.fields.request_ip_region.label'),
          description: I18n.t('admin.stats.fields.request_ip_region.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_ip_city',
          label: I18n.t('admin.stats.fields.request_ip_city.label'),
          description: I18n.t('admin.stats.fields.request_ip_city.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_user_agent',
          label: I18n.t('admin.stats.fields.request_user_agent.label'),
          description: I18n.t('admin.stats.fields.request_user_agent.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_user_agent_family',
          label: I18n.t('admin.stats.fields.request_user_agent_family.label'),
          description: I18n.t('admin.stats.fields.request_user_agent_family.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_user_agent_type',
          label: I18n.t('admin.stats.fields.request_user_agent_type.label'),
          description: I18n.t('admin.stats.fields.request_user_agent_type.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_referer',
          label: I18n.t('admin.stats.fields.request_referer.label'),
          description: I18n.t('admin.stats.fields.request_referer.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_origin',
          label: I18n.t('admin.stats.fields.request_origin.label'),
          description: I18n.t('admin.stats.fields.request_origin.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'api_key',
          label: I18n.t('admin.stats.fields.api_key.label'),
          description: I18n.t('admin.stats.fields.api_key.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'user_email',
          label: I18n.t('admin.stats.fields.user_email.label'),
          description: I18n.t('admin.stats.fields.user_email.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'user_id',
          label: I18n.t('admin.stats.fields.user_id.label'),
          description: I18n.t('admin.stats.fields.user_id.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'response_status',
          label: I18n.t('admin.stats.fields.response_status.label'),
          description: I18n.t('admin.stats.fields.response_status.description_markdown'),
          type: 'integer',
          operators: numberOperators,
        },
        {
          id: 'gatekeeper_denied_code',
          label: I18n.t('admin.stats.fields.gatekeeper_denied_code.label'),
          description: I18n.t('admin.stats.fields.gatekeeper_denied_code.description_markdown'),
          type: 'string',
          operators: selectOperators,
          input: 'select',
          values: {
            'not_found': 'not_found',
            'api_key_missing': 'api_key_missing',
            'api_key_invalid': 'api_key_invalid',
            'api_key_disabled': 'api_key_disabled',
            'api_key_unverified': 'api_key_unverified',
            'api_key_unauthorized': 'api_key_unauthorized',
            'over_rate_limit': 'over_rate_limit',
            'internal_server_error': 'internal_server_error',
            'https_required': 'https_required',
          },
        },
        {
          id: 'response_time',
          label: I18n.t('admin.stats.fields.response_time.label'),
          description: I18n.t('admin.stats.fields.response_time.description_markdown'),
          type: 'integer',
          operators: numberOperators,
        },
        {
          id: 'response_content_type',
          label: I18n.t('admin.stats.fields.response_content_type.label'),
          description: I18n.t('admin.stats.fields.response_content_type.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
      ],
    });

    let query = this.query;
    let rules;
    if(query) {
      rules = JSON.parse(query);
    }

    if(rules) {
      if(rules.condition) {
        $queryBuilder.queryBuilder('setRules', rules);
      }

      this.send('toggleFilterType', 'builder');
    } else if(this.search) {
      this.send('toggleFilterType', 'advanced');
    }
  }

  // eslint-disable-next-line ember/no-observers
  @observes('query')
  updateQueryBuilderRules() {
    let query = this.query;
    let rules;
    if(query) {
      rules = JSON.parse(query);
    }

    if(rules && rules.condition) {
      $('#query_builder').queryBuilder('setRules', rules);
    } else {
      $('#query_builder').queryBuilder('reset');
    }
  }

  // eslint-disable-next-line ember/no-observers
  @observes('allQueryParamValues.start_at', 'allQueryParamValues.end_at')
  updateDateRange() {
    let start = moment(this.allQueryParamValues.start_at, 'YYYY-MM-DD');
    let end = moment(this.allQueryParamValues.end_at, 'YYYY-MM-DD');

    this.dateRangePicker.hideCalendars();
    this.dateRangePicker.setStartDate(start);
    this.dateRangePicker.setEndDate(end);
    $('#reportrange span.text').html(start.format('ll') + ' - ' + end.format('ll'));
  }

  handleDateRangeCalendarShow() {
    this.set('calendarShown', true);
  }

  handleDateRangeCalendarHide() {
    this.set('calendarShown', false);
  }

  handleDateRangeApply(event, picker) {
    // If the user selects a predefined date range (like "Last 7 Days"), then
    // don't set explicit dates in the URL query params. This allows for the
    // URLs that are bookmarked or shared to use relative dates (eg, you'll
    // always see the last 7 days regardless of when the URL was first
    // bookmarked).
    //
    // If the user selects a custom date range, then explicit dates will be set
    // in the URL (so the data is fixed in time).
    //
    // Note that if the user picks "Custom Range" and happens to select dates
    // that correspond with the one of the predefined ranges, then the
    // Bootstrap Date Picker sets the "chosenLabel" as if the user picked the
    // predefined range. To workaround this issue (so any dates picked when
    // "Custom Range" is open are treated the same), we check to see if the
    // "Custom Range" calendars are visible or not.
    let rangeOptions = this.rangeOptions;
    if(rangeOptions[picker.chosenLabel] && !this.calendarShown) {
      let rangeKeys = this.rangeKeys;
      this.setProperties({
        start_at: '',
        end_at: '',
        date_range: rangeKeys[picker.chosenLabel],
      });
    } else {
      this.setProperties({
        start_at: picker.startDate.format('YYYY-MM-DD'),
        end_at: picker.endDate.format('YYYY-MM-DD'),
        // In this case the "date_range" param isn't being used ("start_at" and
        // "end_at" take precedence), so reset it back to the default value
        // (defined in app/controllers/stats/base.js), so it's hidden from the
        // URL.
        date_range: '30d',
      });
    }
  }

  @action
  toggleFilterType(type) {
    $('.filter-type').hide();
    $('#filter_type_' + type).show();
  }

  @action
  clickInterval(interval) {
    this.set('interval', interval);
  }

  @action
  submitForm(event) {
    event.preventDefault();
    if($('#filter_type_advanced').css('display') === 'none') {
      this.set('search', '');
      this.set('query', JSON.stringify($('#query_builder').queryBuilder('getRules')));
    } else {
      this.set('query', '');
      this.set('search', $('#filter_form input[name=search]').val());
    }
  }
}
