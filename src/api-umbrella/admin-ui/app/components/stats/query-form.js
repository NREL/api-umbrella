import Ember from 'ember';

export default Ember.Component.extend({
  enableInterval: false,

  datePickerRanges: {
    'Today': [
      moment().startOf('day'),
      moment().endOf('day'),
    ],
    'Yesterday': [
      moment().subtract(1, 'days'),
      moment().subtract(1, 'days').endOf('day'),
    ],
    'Last 7 Days': [
      moment().subtract(6, 'days'),
      moment().endOf('day'),
    ],
    'Last 30 Days': [
      moment().subtract(29, 'days').startOf('day'),
      moment().endOf('day'),
    ],
    'This Month': [
      moment().startOf('month'),
      moment().endOf('month'),
    ],
    'Last Month': [
      moment().subtract(1, 'month').startOf('month'),
      moment().subtract(1, 'month').endOf('month'),
    ]
  },

  didInsertElement: function() {
    this.updateInterval();
    this.updateDateRange();

    $('#reportrange').daterangepicker({
      ranges: this.datePickerRanges,
      startDate: moment(this.get('start_at'), 'YYYY-MM-DD'),
      endDate: moment(this.get('end_at'), 'YYYY-MM-DD'),
    }, _.bind(this.handleDateRangeChange, this));

    var stringOperators = [
      'begins_with',
      'not_begins_with',
      'equal',
      'not_equal',
      'contains',
      'not_contains',
      'is_null',
      'is_not_null',
    ];

    var selectOperators = [
      'equal',
      'not_equal',
      'is_null',
      'is_not_null',
    ];

    var numberOperators = [
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

    var $queryBuilder = $('#query_builder').queryBuilder({
      plugins: {
        'filter-description': {
          icon: 'fa fa-info-circle',
          mode: 'bootbox',
        },
        'bt-tooltip-errors': null
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
          id: 'request_url',
          label: I18n.t('admin.stats.fields.request_url.label'),
          description: I18n.t('admin.stats.fields.request_url.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
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

    var query = this.get('query');
    var rules;
    if(query) {
      rules = JSON.parse(query);
    }

    if(rules) {
      if(rules.condition) {
        $queryBuilder.queryBuilder('setRules', rules);
      }

      this.send('toggleFilters');
      this.send('toggleFilterType', 'builder');
    } else if(this.get('search')) {
      this.send('toggleFilters');
      this.send('toggleFilterType', 'advanced');
    }
  },

  updateQueryBuilderRules: function() {
    var query = this.get('query');
    var rules;
    if(query) {
      rules = JSON.parse(query);
    }

    if(rules && rules.condition) {
      $('#query_builder').queryBuilder('setRules', rules);
    } else {
      $('#query_builder').queryBuilder('reset');
    }
  }.observes('query'),

  updateInterval: function() {
    var interval = this.get('interval');
    $('#interval_buttons').find('button[value="' + interval + '"]').button('toggle');
  }.observes('interval'),

  updateDateRange: function() {
    var start = moment(this.get('start_at'));
    var end = moment(this.get('end_at'));

    $('#reportrange span.text').html(start.format('MMM D, YYYY') + ' - ' + end.format('MMM D, YYYY'));
  }.observes('start_at', 'end_at'),

  handleDateRangeChange: function(start, end) {
    this.setProperties({
      'start_at': start.format('YYYY-MM-DD'),
      'end_at': end.format('YYYY-MM-DD'),
    });
  },

  actions: {
    toggleFilters: function() {
      var $container = $('#filters_ui');
      var $icon = $('#filter_toggle .fa');
      if($container.is(':visible')) {
        $icon.addClass('fa-caret-right');
        $icon.removeClass('fa-caret-down');
      } else {
        $icon.addClass('fa-caret-down');
        $icon.removeClass('fa-caret-right');
      }

      $container.slideToggle(100);
    },

    toggleFilterType: function(type) {
      $('.filter-type').hide();
      $('#filter_type_' + type).show();
    },

    clickInterval: function(interval) {
      this.set('interval', interval);
    },
  },
});
