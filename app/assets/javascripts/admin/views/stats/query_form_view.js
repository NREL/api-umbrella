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
          label: 'Request: HTTP Method',
          description: 'The HTTP method of the request.<br><em>Example:</em> <code>GET</code>, <code>POST</code>, <code>PUT</code>, <code>DELETE</code>, etc.',
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
          label: 'Request: URL Scheme',
          description: 'The scheme of the original request URL.<br><em>Example:</em>: <code>http</code> or <code>https</code>',
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
          label: 'Request: URL Host',
          description: 'The host of the original request URL.<br><em>Example:</em> <code>example.com</code>',
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_path',
          label: 'Request: URL Path',
          description: 'The path portion of the original request URL.<br><em>Example:</em> <code>/geocode/v1.json</code>',
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_url',
          label: 'Request: Full URL & Query String',
          description: 'The original, complete request URL.<br><em>Example:</em> <code>http://example.com/geocode/v1.json?address=1617+Cole+Blvd+Golden+CO</code><br><em>Note:</em> If you want to simply filter on the host or path portion of the URL, your queries will run better if you use the separate "Request: URL Path" or "Request: URL Host" fields.',
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_ip',
          label: 'Request: IP Address',
          description: 'The IP address of the requestor.<br><em>Example:</em> <code>93.184.216.119</code>',
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_ip_country',
          label: 'Request: IP Country',
          description: 'The 2 letter country code (<a href="http://en.wikipedia.org/wiki/ISO_3166-1_alpha-2" target="_blank">ISO 3166-1</a>) that the IP address geocoded to.<br><em>Example:</em> <code>US</code>',
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_ip_region',
          label: 'Request: IP State/Region',
          description: 'The 2 letter state or region code (<a href="http://en.wikipedia.org/wiki/ISO_3166-2" target="_blank">ISO 3166-2</a>) that the IP address geocoded to.<br><em>Example:</em> <code>CO</code>',
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_ip_city',
          label: 'Request: IP City',
          description: 'The name of the city that the IP address geocoded to.<br><em>Example:</em> <code>Golden</code>',
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'request_user_agent',
          label: 'Request: User Agent',
          description: 'The user agent of the requestor.<br><em>Example:</em> <code>curl/7.33.0</code>',
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'api_key',
          label: 'User: API Key',
          description: 'The API key used to make the request.<br><em>Example:</em> <code>vfcHB9tOyFKc6YbbdDsE8plxtFHvp9zXIJWAtaep</code>',
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'user_email',
          label: 'User: E-mail',
          description: 'The e-mail address associated with the API key used to make the request.<br><em>Example:</em> <code>john.doe@example.com</code>',
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'user_id',
          label: 'User: ID',
          description: 'The user ID associated with the API key used to make the request.<br><em>Example:</em> <code>ad2d94b6-e0f8-4e26-b1a6-1bc6b12f3d76</code>',
          type: 'string',
          operators: stringOperators,
        },
        {
          id: 'response_status',
          label: 'Response: HTTP Status Code',
          description: 'The HTTP status code returned for the response.<br><em>Example:</em> <code>200</code>, <code>403</code>, <code>429</code>, etc.',
          type: 'integer',
          operators: numberOperators,
        },
        {
          id: 'response_time',
          label: 'Response: Load Time',
          description: 'The total amount of time taken to respond to the request (in milliseconds)',
          type: 'integer',
          operators: numberOperators,
        },
        {
          id: 'response_content_type',
          label: 'Response: Content Type',
          description: 'The content type of the response.<br><em>Example:</em> <code>application/json; charset=utf-8</code>',
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
      $queryBuilder.queryBuilder('setRules', rules);
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

    if(rules) {
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
