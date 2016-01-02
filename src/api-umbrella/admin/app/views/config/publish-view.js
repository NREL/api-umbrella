Admin.ConfigPublishView = Ember.View.extend({
  didInsertElement: function() {
    this.$toggleCheckboxesLink = $('#toggle_checkboxes');
    $('#publish_form').on('change', ':checkbox', _.bind(this.onCheckboxChange, this));

    var $checkboxes = $('#publish_form :checkbox');
    if($checkboxes.length === 1) {
      $checkboxes.prop('checked', true);
      this.onCheckboxChange();
    }

    this.$().find('.diff-active-yaml').each(function() {
      var activeYaml = $(this).text();
      var pendingYaml = $(this).siblings('.diff-pending-yaml').text();

      var diff = JsDiff.diffWords(activeYaml, pendingYaml);

      var fragment = document.createDocumentFragment();
      for(var i = 0; i < diff.length; i++) {
        if(diff[i].added && diff[i + 1] && diff[i + 1].removed) {
          var swap = diff[i];
          diff[i] = diff[i + 1];
          diff[i + 1] = swap;
        }

        var node;
        if(diff[i].removed) {
          node = document.createElement('del');
          node.appendChild(document.createTextNode(diff[i].value));
        } else if(diff[i].added) {
          node = document.createElement('ins');
          node.appendChild(document.createTextNode(diff[i].value));
        } else {
          node = document.createTextNode(diff[i].value);
        }

        fragment.appendChild(node);
      }

      var diffOutput = $(this).siblings('.config-diff');
      diffOutput.html(fragment);
    });
  },

  onCheckboxChange: function() {
    var $unchecked = $('#publish_form :checkbox').not(':checked');
    if($unchecked.length > 0) {
      this.$toggleCheckboxesLink.text(this.$toggleCheckboxesLink.data('check-all'));
    } else {
      this.$toggleCheckboxesLink.text(this.$toggleCheckboxesLink.data('uncheck-all'));
    }
  },

  actions: {
    toggleAllCheckboxes: function() {
      var $checkboxes = $('#publish_form :checkbox');
      var $unchecked = $('#publish_form :checkbox').not(':checked');

      if($unchecked.length > 0) {
        $checkboxes.prop('checked', true);
      } else {
        $checkboxes.prop('checked', false);
      }

      this.onCheckboxChange();
    }
  }
});
