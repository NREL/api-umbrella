Admin.ConfigPublishView = Ember.View.extend({
  didInsertElement: function() {
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
});
