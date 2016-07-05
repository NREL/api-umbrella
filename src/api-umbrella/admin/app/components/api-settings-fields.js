import Ember from 'ember';

export default Ember.Component.extend({
  requireHttpsOptions: [
    { id: null, name: I18n.t('admin.api.settings.require_https_options.inherit') },
    { id: 'required_return_error', name: I18n.t('admin.api.settings.require_https_options.required_return_error') },
    { id: 'required_return_redirect', name: I18n.t('admin.api.settings.require_https_options.required_return_redirect') },
    { id: 'transition_return_error', name: I18n.t('admin.api.settings.require_https_options.transition_return_error') },
    { id: 'transition_return_redirect', name: I18n.t('admin.api.settings.require_https_options.transition_return_redirect') },
    { id: 'optional', name: I18n.t('admin.api.settings.require_https_options.optional') },
  ],

  disableApiKeyOptions: [
    { id: null, name: I18n.t('admin.api.settings.disable_api_key_options.inherit') },
    { id: false, name: I18n.t('admin.api.settings.disable_api_key_options.required') },
    { id: true, name: I18n.t('admin.api.settings.disable_api_key_options.disabled') },
  ],

  apiKeyVerificationLevelOptions: [
    { id: null, name: I18n.t('admin.api.settings.api_key_verification_level_options.inherit') },
    { id: 'none', name: I18n.t('admin.api.settings.api_key_verification_level_options.none') },
    { id: 'transition_email', name: I18n.t('admin.api.settings.api_key_verification_level_options.transition_email') },
    { id: 'required_email', name: I18n.t('admin.api.settings.api_key_verification_level_options.required_email') },
  ],

  roleOptions: Ember.computed(function() {
    return this.get('store').findAll('api-user-role');
    // Don't cache this property, so we can rely on refreshing the underlying
    // model to refresh the options.
  }),
});
