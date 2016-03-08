import Ember from 'ember';
import Resolver from 'ember/resolver';
import loadInitializers from 'ember/load-initializers';
import config from './config/environment';

let App;

Ember.MODEL_FACTORY_INJECTIONS = true;

App = Ember.Application.extend({
  modulePrefix: config.modulePrefix,
  podModulePrefix: config.podModulePrefix,
  Resolver
});

loadInitializers(App, config.modulePrefix);

//= require_self
//= require ./common_validations
//= require_tree ./models
//= require ./controllers/apis/nested_form_controller
//= require ./controllers/apis/sortable_controller
//= require_tree ./components
//= require_tree ./controllers
//= require_tree ./views
//= require_tree ./helpers
//= require_tree ./templates
//= require ./router
//= require_tree ./routes

//Ember.LOG_BINDINGS = true

(function() {
  var versionParts = Ember.VERSION.split('.');
  var major = parseInt(versionParts[0], 10);
  var minor = parseInt(versionParts[1], 10);
  var patch = parseInt(versionParts[2], 10);
  if(major > 1 || (major === 1 && (minor > 1 || patch > 2))) {
    Ember.Logger.warn('WARNING: New Ember version detected. URL hash monkey patch possibly no longer needed or broken. Check for compatibility.');
  }

  var get = Ember.get, set = Ember.set;

  // Fix URL hash parsing across browsers. Because we're putting query
  // parameters in the URL, we expect special characters which escape
  // differently across browsers with location.hash. So this is a monkey patch
  // to use location.href instead.
  // https://github.com/emberjs/ember.js/issues/3000
  // https://github.com/emberjs/ember.js/issues/3263
  //
  // All of this should be revisited once query-params lands, since this will
  // probably clean this up: https://github.com/emberjs/ember.js/pull/3182
  Ember.HashLocation.reopen({
    getURL: function() {
      var href = get(this, 'location').href;

      var hashIndex = href.indexOf('#');
      if (hashIndex === -1) {
        return '';
      } else {
        return href.substr(hashIndex + 1);
      }
    },

    onUpdateURL: function(callback) {
      var self = this;
      var guid = Ember.guidFor(this);

      Ember.$(window).on('hashchange.ember-location-'+guid, function() {
        Ember.run(function() {
          var path = self.getURL();
          if (get(self, 'lastSetURL') === path) { return; }

          set(self, 'lastSetURL', null);

          callback(path);
        });
      });
    },
  });
})();

App.APIUmbrellaRESTAdapter = Ember.RESTAdapter.extend({
  ajaxSettings: function(url, method) {
    return {
      url: url,
      type: method,
      dataType: 'json',
      headers: {
        'X-Api-Key': webAdminAjaxApiKey
      }
    };
  }
});

$.ajaxPrefilter(function(options) {
  options.headers = options.headers || {};
  options.headers['X-Api-Key'] = webAdminAjaxApiKey;
});

// A mixin that provides the default ajax save behavior for our forms.
App.Save = Ember.Mixin.create({
  save: function(options) {
    var button = $('#save_button');
    button.button('loading');

    // Force dirty to force save (ember-model's dirty tracking fails to
    // account for changes in nested, non-association objects:
    // http://git.io/sbS1mg This is mainly for ApiSettings's errorTemplates
    // and errorDataYamlStrings, but we've seen enough funkiness elsewhere,
    // it seems worth disabling for now).
    this.set('model.isDirty', true);

    this.get('model').save().then(_.bind(function() {
      button.button('reset');
      new PNotify({
        type: 'success',
        title: 'Saved',
        text: (_.isFunction(options.message)) ? options.message(this.get('model')) : options.message,
      });

      this.transitionToRoute(options.transitionToRoute);
    }, this), _.bind(function(response) {
      // Set the errors from the server response on a "serverErrors" property
      // for the error-messages component display.
      try {
        this.set('model.serverErrors', response.responseJSON.errors);
      } catch(e) {
        this.set('model.serverErrors', response.responseText);
      }

      button.button('reset');
      $.scrollTo('#error_messages', { offset: -50, duration: 200 });
    }, this));
  },
});

App.DataTablesHelpers = {
  renderEscaped: function(value, type) {
    if(type === 'display' && value) {
      return _.escape(value);
    }

    return value;
  },

  renderListEscaped: function(value, type) {
    if(type === 'display' && value) {
      if(_.isArray(value)) {
        return _.map(value, function(v) { return _.escape(v); }).join('<br>');
      } else {
        return _.escape(value);
      }
    }

    return value;
  },

  renderTime: function(value, type) {
    if(type === 'display' && value && value !== '-') {
      return moment(value).format('YYYY-MM-DD HH:mm:ss');
    }

    return value;
  },
};

export default App;
