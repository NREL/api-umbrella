Admin.ApisSortableController = Ember.ArrayController.extend({
  reorderable: function() {
    var length = this.get('length');
    return (length && length > 1);
  }.property('length'),

  updateSortOrder: function(indexes) {
    this.forEach(function(record) {
      var index = indexes[record.get('id')];
      record.set('sortOrder', index);
    });
  },

  reorderCollection: function(containerId) {
    var $container = $('#' + containerId);
    var $buttonText = $container.find('.reorder-button-text');

    if($container.hasClass('reorder-active')) {
      $buttonText.text($buttonText.data('originalText'));
    } else {
      $buttonText.data('originalText',  $buttonText.text());
      $buttonText.text('Done');
    }

    $container.toggleClass('reorder-active');

    var controller = this;
    $container.find('tbody').sortable({
      handle: '.reorder-handle',
      placeholder: 'reorder-placeholder',
      helper: function(event, ui) {
        ui.children().each(function() {
          $(this).width($(this).width());
        });
        return ui;
      },
      stop: function(event, ui) {
        var indexes = {};
        $(this).find('tr').each(function(index) {
          indexes[$(this).data('id')] = index;
        });

        controller.updateSortOrder(indexes);
      },
    });
  },
});
