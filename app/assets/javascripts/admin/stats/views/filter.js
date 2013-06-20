var FilterView = Backbone.Marionette.ItemView.extend({
  template: "#filter_template",

  events: {
    "click #interval_buttons button": "handleIntervalChange",
    "change select": "submit",
    "change #region": "submit",
  },

  ui: {
    form: "form",
    search: "#search",
    searchField: "#search_field",
    interval: "#interval",
    intervalButtons: "#interval_buttons",
    start: "#start",
    end: "#end",
  },

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

  onRender: function() {
    this.ui.form.submit(_.bind(this.submit, this));

    this.$el.find("#query_syntax_help").popover({
      html: true,
      placement: 'bottom',
      content: this.$el.find("#query_syntax_help_content").html(),
    }).click(function(e) { 
      e.preventDefault(); 
    });

    $("#query_syntax_help").popover('show');
  },

  setFromQuery: function(query) {
    this.ui.form.deserialize(query, { noEvents: true });

    var interval = this.ui.interval.val();
    this.ui.form.find("button[value='" + interval + "']").button('toggle');

    var start = moment(this.ui.start.val());
    var end = moment(this.ui.end.val());
    this.setDateRangeDisplay(start, end);

    $('#reportrange').daterangepicker({
        ranges: this.datePickerRanges,
        startDate: moment(this.ui.start.val(), 'YYYY-MM-DD'),
        endDate: moment(this.ui.end.val(), 'YYYY-MM-DD'),
      }, _.bind(this.handleDateRangeChange, this));
  },

  submit: function(event) {
    if(event) {
      event.preventDefault();
    }

    var query = this.ui.form.serialize();
    StatsApp.router.navigate(StatsApp.router.getCurrentMode() + '/' + query, { trigger: true });
  },

  handleIntervalChange: function(event) {
    this.ui.interval.val($(event.target).val());
    this.submit();
  },

  setDateRange: function(start, end) {
    this.ui.start.val(start.format("YYYY-MM-DD"));
    this.ui.end.val(end.format("YYYY-MM-DD"));
    this.setDateRangeDisplay(start, end);
  },

  setDateRangeDisplay: function(start, end) {
    $('#reportrange span.text').html(start.format('MMM D, YYYY') + ' - ' + end.format('MMM D, YYYY'));
  },

  handleDateRangeChange: function(start, end) {
    this.setDateRange(start, end);
    this.submit();
  },

  disableSearch: function() {
    this.ui.searchField.hide();
    this.ui.search.prop('disabled', true);
  },

  enableSearch: function() {
    this.ui.search.prop('disabled', false);
    this.ui.searchField.show();
  },

  disableInterval: function() {
    this.ui.intervalButtons.hide();
    this.ui.interval.prop('disabled', true);
  },

  enableInterval: function() {
    this.ui.interval.prop('disabled', false);
    this.ui.intervalButtons.show();
  },
});

