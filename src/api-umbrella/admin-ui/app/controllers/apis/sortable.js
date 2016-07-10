import Ember from 'ember';

export default Ember.Controller.extend({
  reorderable: function() {
    let length = this.get('length');
    return (length && length > 1);
  }.property('length'),

  updateSortOrder(indexes) {
    this.forEach(function(record) {
      let index = indexes[record.get('id')];
      record.set('sortOrder', index);
    });
  },

  reorderCollection(containerId) {
    let $container = $('#' + containerId);
    let $buttonText = $container.find('.reorder-button-text');

    if($container.hasClass('reorder-active')) {
      $buttonText.text($buttonText.data('originalText'));
    } else {
      $buttonText.data('originalText',  $buttonText.text());
      $buttonText.text('Done');
    }

    $container.toggleClass('reorder-active');

    let controller = this;
    $container.find('tbody').sortable({
      handle: '.reorder-handle',
      placeholder: 'reorder-placeholder',
      helper(event, ui) {
        ui.children().each(function() {
          $(this).width($(this).width());
        });
        return ui;
      },
      stop() {
        let indexes = {};
        $(this).find('tr').each(function(index) {
          indexes[$(this).data('id')] = index;
        });

        controller.updateSortOrder(indexes);
      },
    });
  },
});
