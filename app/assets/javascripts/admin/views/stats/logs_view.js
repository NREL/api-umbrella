Admin.StatsLogsView = Ember.View.extend({
/*
  defaultQuery: {
    interval: 'day',
    tz: jstz.determine().name(),
    start: moment().subtract('days', 29).format('YYYY-MM-DD'),
    end: moment().format('YYYY-MM-DD'),
  },
  */

  datePickerRanges: {
    'Today': [
      moment().startOf('day'),
      moment().endOf('day'),
    ],
    'Yesterday': [
      moment().subtract('days', 1),
      moment().subtract('days', 1).endOf('day'),
    ],
    'Last 7 Days': [
      moment().subtract('days', 6),
      moment().endOf('day'),
    ],
    'Last 30 Days': [
      moment().subtract('days', 29).startOf('day'),
      moment().endOf('day'),
    ],
    'This Month': [
      moment().startOf('month'),
      moment().endOf('month'),
    ],
    'Last Month': [
      moment().subtract('month', 1).startOf('month'),
      moment().subtract('month', 1).endOf('month'),
    ]
  },

  didInsertElement: function() {
    this.updateInterval();
    this.updateDateRange();

    $('#reportrange').daterangepicker({
      ranges: this.datePickerRanges,
      startDate: moment(this.get('controller.query.start'), 'YYYY-MM-DD'),
      endDate: moment(this.get('controller.query.end'), 'YYYY-MM-DD'),
    }, _.bind(this.handleDateRangeChange, this));
  },

  updateInterval: function() {
    var interval = this.get('controller.query.interval');
    $("#interval_buttons").find("button[value='" + interval + "']").button('toggle');
  }.observes('controller.query.interval'),

  updateDateRange: function() {
    var start = moment(this.get('controller.query.start'));
    var end = moment(this.get('controller.query.end'));

    $('#reportrange span.text').html(start.format('MMM D, YYYY') + ' - ' + end.format('MMM D, YYYY'));
  }.observes('controller.query.start', 'controller.query.end'),

  handleDateRangeChange: function(start, end) {
    this.set('controller.query.start', start.format("YYYY-MM-DD"));
    this.set('controller.query.end', end.format("YYYY-MM-DD"));
  },

  actions: {
    clickInterval: function(interval) {
      this.set('controller.query.interval', interval);
      console.info(arguments);
    },
  },
});
