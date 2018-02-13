import Ember from 'ember';
import I18n from 'npm:i18n-js';

export default Ember.Component.extend({
  requireHttpsOptions: [
    { id: null, name: I18n.t('admin.api.settings.require_https_options.inherit') },
    { id: 'required_return_error', name: I18n.t('admin.api.settings.require_https_options.required_return_error') },
    { id: 'transition_return_error', name: I18n.t('admin.api.settings.require_https_options.transition_return_error') },
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

  requireIdpOptions: [
    { id: null, name: I18n.t('admin.api.settings.require_idp_options.inherit') },
    { id: 'none', name: I18n.t('admin.api.settings.require_idp_options.none') },
    { id: 'fiware-oauth2', name: "FIWARE" },
    { id: 'github-oauth2', name: "GitHub" },
    { id: 'facebook-oauth2', name: "Facebook" },
    { id: 'google-oauth2', name: "Google" },
  ],

  passApiKeyOptions: [
    { id: 'header', name: I18n.t('admin.api.settings.pass_api_key_header') },
    { id: 'param', name: I18n.t('admin.api.settings.pass_api_key_param') },
  ],

  anonymousRateLimitBehaviorOptions: [
    { id: 'ip_fallback', name: 'IP Fallback - API key rate limits are applied as IP limits' },
    { id: 'ip_only', name: 'IP Only - API key rate limits are ignored (only IP based limits are applied)' },
  ],

  authenticatedRateLimitBehaviorOptions: [
    { id: 'all', name: 'All Limits - Both API key rate limits and IP based limits are applied' },
    { id: 'api_key_only', name: 'API Key Only - IP based rate limits are ignored (only API key limits are applied)' },
  ],
});
