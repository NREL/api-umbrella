Admin.StatsQueryFormView = Ember.View.extend({
  templateName: 'stats/_query_form',

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
      startDate: moment(this.get('controller.query.params.start_at'), 'YYYY-MM-DD'),
      endDate: moment(this.get('controller.query.params.end_at'), 'YYYY-MM-DD'),
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
          label: polyglot.t('admin.stats.fields.request_method.label'),
          description: polyglot.t('admin.stats.fields.request_method.description_markdown'),
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
          label: polyglot.t('admin.stats.fields.request_scheme.label'),
          description: polyglot.t('admin.stats.fields.request_scheme.description_markdown'),
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
          label: polyglot.t('admin.stats.fields.request_host.label'),
          description: polyglot.t('admin.stats.fields.request_host.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_path',
          label: polyglot.t('admin.stats.fields.request_path.label'),
          description: polyglot.t('admin.stats.fields.request_path.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_url',
          label: polyglot.t('admin.stats.fields.request_url.label'),
          description: polyglot.t('admin.stats.fields.request_url.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_ip',
          label: polyglot.t('admin.stats.fields.request_ip.label'),
          description: polyglot.t('admin.stats.fields.request_ip.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_ip_country',
          label: polyglot.t('admin.stats.fields.request_ip_country.label'),
          description: polyglot.t('admin.stats.fields.request_ip_country.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_ip_region',
          label: polyglot.t('admin.stats.fields.request_ip_region.label'),
          description: polyglot.t('admin.stats.fields.request_ip_region.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_ip_city',
          label: polyglot.t('admin.stats.fields.request_ip_city.label'),
          description: polyglot.t('admin.stats.fields.request_ip_city.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_user_agent',
          label: polyglot.t('admin.stats.fields.request_user_agent.label'),
          description: polyglot.t('admin.stats.fields.request_user_agent.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'api_key',
          label: polyglot.t('admin.stats.fields.api_key.label'),
          description: polyglot.t('admin.stats.fields.api_key.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'user_email',
          label: polyglot.t('admin.stats.fields.user_email.label'),
          description: polyglot.t('admin.stats.fields.user_email.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'user_id',
          label: polyglot.t('admin.stats.fields.user_id.label'),
          description: polyglot.t('admin.stats.fields.user_id.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'response_status',
          label: polyglot.t('admin.stats.fields.response_status.label'),
          description: polyglot.t('admin.stats.fields.response_status.description_markdown'),
          type: 'integer',
          operators: numberOperators,
        },
        {
          id: 'gatekeeper_denied_code',
          label: polyglot.t('admin.stats.fields.gatekeeper_denied_code.label'),
          description: polyglot.t('admin.stats.fields.gatekeeper_denied_code.description_markdown'),
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
          label: polyglot.t('admin.stats.fields.response_time.label'),
          description: polyglot.t('admin.stats.fields.response_time.description_markdown'),
          type: 'integer',
          operators: numberOperators,
        },
        {
          id: 'response_content_type',
          label: polyglot.t('admin.stats.fields.response_content_type.label'),
          description: polyglot.t('admin.stats.fields.response_content_type.description_markdown'),
          type: 'string',
          operators: stringOperators,
        },
      ],
    });

    var query = this.get('controller.query.params.query');
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
    } else if(this.get('controller.query.params.search')) {
      this.send('toggleFilters');
      this.send('toggleFilterType', 'advanced');
    }
  },

  updateQueryBuilderRules: function() {
    var query = this.get('controller.query.params.query');
    var rules;
    if(query) {
      rules = JSON.parse(query);
    }

    if(rules && rules.condition) {
      $('#query_builder').queryBuilder('setRules', rules);
    } else {
      $('#query_builder').queryBuilder('reset');
    }
  }.observes('controller.query.params.query'),

  updateInterval: function() {
    var interval = this.get('controller.query.params.interval');
    $('#interval_buttons').find('button[value="' + interval + '"]').button('toggle');
  }.observes('controller.query.params.interval'),

  updateDateRange: function() {
    var start = moment(this.get('controller.query.params.start_at'));
    var end = moment(this.get('controller.query.params.end_at'));

    $('#reportrange span.text').html(start.format('MMM D, YYYY') + ' - ' + end.format('MMM D, YYYY'));
  }.observes('controller.query.params.start_at', 'controller.query.params.end_at'),

  handleDateRangeChange: function(start, end) {
    this.setProperties({
      'controller.query.params.start_at': start.format('YYYY-MM-DD'),
      'controller.query.params.end_at': end.format('YYYY-MM-DD'),
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
      this.set('controller.query.params.interval', interval);
    },
  },
});
