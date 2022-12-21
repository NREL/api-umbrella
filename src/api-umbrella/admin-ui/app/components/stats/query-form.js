import 'daterangepicker';

// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import { inject } from '@ember/service';
import { tagName } from '@ember-decorators/component';
import { observes } from '@ember-decorators/object';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import classic from 'ember-classic-decorator';
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
          label: t('Request: HTTP Method'),
          description: t('The HTTP method of the request.\n*Example:* `GET`, `POST`, `PUT`, `DELETE`, etc.'),
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
          label: t('Request: URL Scheme'),
          description: t('The scheme of the original request URL.\n*Example:* `http` or `https`'),
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
          label: t('Request: URL Host'),
          description: t('The host of the original request URL.\n*Example:* `example.com`'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_path',
          label: t('Request: URL Path'),
          description: t('The path of the original request URL.\n*Example:* `/geocode/v1.json`'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_url_query',
          label: t('Request: Query String'),
          description: t('The query string of the original request URL.\n*Example:* `address=1617+Cole+Blvd+Golden+CO&foo=bar`'),
          type: 'string',
          operators: stringOperators,
        },
        ...((window.apiUmbrellaConfig.elasticsearch.template_version < 2) ? [{
          id: 'request_url',
          label: t('Request: Full URL & Query String'),
          description: t('The original, complete request URL.\n*Example:* `http://example.com/geocode/v1.json?address=1617+Cole+Blvd+Golden+CO`\n*Note:* If you want to simply filter on the host or path portion of the URL, your queries will run better if you use the separate "Request: URL Path" or "Request: URL Host" fields.'),
          type: 'string',
          operators: stringOperators,
        }] : []),
        {
          id: 'request_ip',
          label: t('Request: IP Address'),
          description: t('The IP address of the requestor.\n*Example:* `93.184.216.119`'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_ip_country',
          label: t('Request: IP Country'),
          description: t('The 2 letter country code (<a href="http://en.wikipedia.org/wiki/ISO_3166-1_alpha-2" target="_blank">ISO 3166-1</a>) that the IP address geocoded to.\n*Example:* `US`'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_ip_region',
          label: t('Request: IP State/Region'),
          description: t('The 2 letter state or region code (<a href="http://en.wikipedia.org/wiki/ISO_3166-2" target="_blank">ISO 3166-2</a>) that the IP address geocoded to.\n*Example:* `CO`'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_ip_city',
          label: t('Request: IP City'),
          description: t('The name of the city that the IP address geocoded to.\n*Example:* `Golden`'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_user_agent',
          label: t('Request: User Agent'),
          description: t('The full user agent string of the requestor.\n*Example:* `curl/7.33.0`'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_user_agent_family',
          label: t('Request: User Agent Family'),
          description: t('The overall family of the user agent.\n*Example:* `Chrome`'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_user_agent_type',
          label: t('Request: User Agent Type'),
          description: t('The type of user agent.\n*Example:* `Browser`'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_referer',
          label: t('Request: Referer'),
          description: t('The `Referer` header sent on the request\n*Example:* `https://example.com/foo`'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_origin',
          label: t('Request: Origin'),
          description: t('The `Origin` header sent on the request\n*Example:* `https://example.com`'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'api_key',
          label: t('User: API Key'),
          description: t('The API key used to make the request.\n*Example:* `vfcHB9tOyFKc6YbbdDsE8plxtFHvp9zXIJWAtaep`'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'user_email',
          label: t('User: E-mail'),
          description: t('The e-mail address associated with the API key used to make the request.\n*Example:* `john.doe@example.com`'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'user_id',
          label: t('User: ID'),
          description: t('The user ID associated with the API key used to make the request.\n*Example:* `ad2d94b6-e0f8-4e26-b1a6-1bc6b12f3d76`'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'response_status',
          label: t('Response: HTTP Status Code'),
          description: t('The HTTP status code returned for the response.\n*Example:* `200`, `403`, `429`, etc.'),
          type: 'integer',
          operators: numberOperators,
        },
        {
          id: 'gatekeeper_denied_code',
          label: t('Response: API Umbrella Denied Code'),
          description: t('If API Umbrella is responsible for blocking the request, this code value describes the reason for the block.\n*Example:* `api_key_missing`, `over_rate_limit`, etc.'),
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
          label: t('Response: Load Time'),
          description: t('The total amount of time taken to respond to the request (in milliseconds)'),
          type: 'integer',
          operators: numberOperators,
        },
        {
          id: 'response_content_type',
          label: t('Response: Content Type'),
          description: t('The content type of the response.\n*Example:* `application/json; charset=utf-8`'),
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
      this.start_at = '';
      this.end_at = '';
      this.date_range = rangeKeys[picker.chosenLabel];
    } else {
      this.start_at = picker.startDate.format('YYYY-MM-DD');
      this.end_at = picker.endDate.format('YYYY-MM-DD');
      // In this case the "date_range" param isn't being used ("start_at" and
      // "end_at" take precedence), so reset it back to the default value
      // (defined in app/controllers/stats/base.js), so it's hidden from the
      // URL.
      this.date_range = '30d';
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
