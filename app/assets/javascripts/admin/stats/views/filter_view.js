var FilterView = Backbone.View.extend({
  el: "#filter_form",

  events: {
    "click #interval_buttons button": "handleIntervalChange",
    "change select": "submit",
    "change #region": "submit",
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

  initialize: function() {
    this.$loadingOverlay = $('#loading_overlay');
  },

  render: function() {
    $('#reportrange').daterangepicker({
        ranges: this.datePickerRanges,
        startDate: moment(this.$el.find("#start").val(), 'YYYY-MM-DD'),
        endDate: moment(this.$el.find("#end").val(), 'YYYY-MM-DD'),
      }, _.bind(this.handleDateRangeChange, this));
  },

  setFromParams: function(params) {
    this.$el.deserialize(params, { noEvents: true });

    var interval = this.$el.find("#interval").val();
    this.$el.find("button[value='" + interval + "']").button('toggle');

    var start = moment(this.$el.find("#start").val());
    var end = moment(this.$el.find("#end").val());
    this.setDateRangeDisplay(start, end);
  },

  submit: function() {
    var query = this.$el.serialize();
    app.navigate(query);
    this.loadResults(query);
  },

  loadResults: function(query) {
    this.model.setQuery(query);

    this.showSpinner();
    this.model.fetch({
      //success: _.bind(this.hideSpinner, this),
      //error: _.bind(this.hideSpinner, this),
    });
  },

  showSpinner: function() {
    if(!this.spinner) {
      var opts = {
        lines: 13, // The number of lines to draw
        length: 20, // The length of each line
        width: 10, // The line thickness
        radius: 30, // The radius of the inner circle
        corners: 1, // Corner roundness (0..1)
        rotate: 0, // The rotation offset
        direction: 1, // 1: clockwise, -1: counterclockwise
        color: '#000', // #rgb or #rrggbb
        speed: 1, // Rounds per second
        trail: 60, // Afterglow percentage
        shadow: false, // Whether to render a shadow
        hwaccel: true, // Whether to use hardware acceleration
        className: 'spinner', // The CSS class to assign to the spinner
        zIndex: 2e9, // The z-index (defaults to 2000000000)
        top: 'auto', // Top position relative to parent in px
        left: 'auto' // Left position relative to parent in px
      };

      this.spinner = new Spinner(opts)
    }

    this.$loadingOverlay.show();
    this.spinner.spin(this.$loadingOverlay[0]);
  },

  hideSpinner: function() {
    if(this.spinner) {
      this.spinner.stop();
    }

    this.$loadingOverlay.hide();
  },

  handleIntervalChange: function(event) {
    $("#interval").val($(event.target).val());
    this.submit();
  },

  setDateRange: function(start, end) {
    $("#start").val(start.format("YYYY-MM-DD"));
    $("#end").val(end.format("YYYY-MM-DD"));
    this.setDateRangeDisplay(start, end);
  },

  setDateRangeDisplay: function(start, end) {
    $('#reportrange span').html(start.format('MMM D, YYYY') + ' - ' + end.format('MMM D, YYYY'));
  },

  handleDateRangeChange: function(start, end) {
    this.setDateRange(start, end);
    this.submit();
  },
});

