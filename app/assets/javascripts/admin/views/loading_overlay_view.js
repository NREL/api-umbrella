Admin.LoadingOverlayView = Ember.View.extend({
  classNames: ['loading-overlay'],
  attributeBindings: ['style'],
  style: 'display: none;',

  init: function() {
    this._super();

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

    this.spinner = new Spinner(opts);
  },

  didInsertElement: function() {
    if(this.get('isLoading')) {
      this.showSpinner();
    }
  },

  showSpinner: function() {
    this.$().show();
    this.spinner.spin(this.$()[0]);
  },

  hideSpinner: function() {
    if(this.spinner) {
      this.spinner.stop();
    }

    this.$().hide();
  },

  toggleSpinner: function() {
    if(this.get('isLoading')) {
      this.showSpinner();
    } else {
      this.hideSpinner();
    }
  }.observes('isLoading'),
});
