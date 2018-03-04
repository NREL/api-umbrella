import $ from 'jquery';
import Component from '@ember/component';
import PNotify from 'npm:pnotify';
import { computed } from '@ember/object';

export default Component.extend({
  didInsertElement() {
    this.$submitButton = $('#publish_button');
    this.$toggleCheckboxesLink = $('#toggle_checkboxes');
    $('#publish_form').on('change', ':checkbox', _.bind(this.onCheckboxChange, this));

    let $checkboxes = $('#publish_form :checkbox');
    if($checkboxes.length === 1) {
      $checkboxes.prop('checked', true);
    }

    this.onCheckboxChange();

    this.$().find('.diff-active-yaml').each(function() {
      let activeYaml = $(this).text();
      let pendingYaml = $(this).siblings('.diff-pending-yaml').text();

      let diff = JsDiff.diffWords(activeYaml, pendingYaml);

      let fragment = document.createDocumentFragment();
      for(let i = 0; i < diff.length; i++) {
        if(diff[i].added && diff[i + 1] && diff[i + 1].removed) {
          let swap = diff[i];
          diff[i] = diff[i + 1];
          diff[i + 1] = swap;
        }

        let node;
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

      let diffOutput = $(this).siblings('.config-diff');
      diffOutput.html(fragment);
    });
  },

  onCheckboxChange() {
    let $unchecked = $('#publish_form :checkbox:not(:checked)');
    if($unchecked.length > 0) {
      this.$toggleCheckboxesLink.text(this.$toggleCheckboxesLink.data('check-all'));
    } else {
      this.$toggleCheckboxesLink.text(this.$toggleCheckboxesLink.data('uncheck-all'));
    }

    let $checked = $('#publish_form :checkbox:checked');
    if($checked.length > 0) {
      this.$submitButton.prop('disabled', false);
    } else {
      this.$submitButton.prop('disabled', true);
    }
  },

  hasChanges: computed('model.config.apis.{new.@each,modified.@each,deleted.@each}', 'model.config.website_backends.{new.@each,modified.@each,deleted.@each}', function() {
    let newApis = this.get('model.config.apis.new');
    let modifiedApis = this.get('model.config.apis.modified');
    let deletedApis = this.get('model.config.apis.deleted');
    let newWebsiteBackends = this.get('model.config.website_backends.new');
    let modifiedWebsiteBackends = this.get('model.config.website_backends.modified');
    let deletedWebsiteBackends = this.get('model.config.website_backends.deleted');

    if(newApis.length > 0 || modifiedApis.length > 0 || deletedApis.length > 0 || newWebsiteBackends.length > 0 || modifiedWebsiteBackends.length > 0 || deletedWebsiteBackends.length > 0) {
      return true;
    } else {
      return false;
    }
  }),

  actions: {
    toggleAllCheckboxes() {
      let $checkboxes = $('#publish_form :checkbox');
      let $unchecked = $('#publish_form :checkbox').not(':checked');

      if($unchecked.length > 0) {
        $checkboxes.prop('checked', true);
      } else {
        $checkboxes.prop('checked', false);
      }

      this.onCheckboxChange();
    },

    publish() {
      let form = $('#publish_form');

      let button = $('#publish_button');
      button.button('loading');

      $.ajax({
        url: '/api-umbrella/v1/config/publish',
        type: 'POST',
        data: form.serialize(),
      }).then(_.bind(function() {
        button.button('reset');
        new PNotify({
          type: 'success',
          title: 'Published',
          text: 'Successfully published the configuration<br>Changes should be live in a few seconds...',
        });

        // eslint-disable-next-line ember/closure-actions
        this.sendAction('refreshCurrentRouteController');
      }, this), function(response) {
        let message = '<h3>Error</h3>';
        try {
          let errors = response.responseJSON.errors;
          for(let prop in errors) {
            message += prop + ': ' + errors[prop].join(', ') + '<br>';
          }
        } catch(e) {
          message = 'An unexpected error occurred: ' + response.responseText;
        }

        button.button('reset');
        // eslint-disable-next-line no-console
        console.error(message);
        bootbox.alert(message);
      });
    },
  },
});
