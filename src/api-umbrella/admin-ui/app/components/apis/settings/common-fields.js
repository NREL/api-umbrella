import Ember from 'ember';
import i18n from 'api-umbrella-admin-ui/utils/i18n';

export default Ember.Component.extend({
  requireHttpsOptions: [
    { id: null, name: i18n.t('admin.api.settings.require_https_options.inherit') },
    { id: 'required_return_error', name: i18n.t('Required - HTTP requests will receive a message to use HTTPS') },
    { id: 'transition_return_error', name: i18n.t('Transitionary - Optional for existing API keys, required for new API keys') },
    { id: 'optional', name: i18n.t('Optional - HTTPS is optional') },
  ],

  disableApiKeyOptions: [
    { id: null, name: i18n.t('Inherit (default - required)') },
    { id: false, name: i18n.t('Required - API keys are mandatory') },
    { id: true, name: i18n.t('Disabled - API keys are optional') },
  ],

  apiKeyVerificationLevelOptions: [
    { id: null, name: i18n.t('Inherit (default - none)') },
    { id: 'none', name: i18n.t('None - API keys can be used without any verification') },
    { id: 'transition_email', name: i18n.t('E-mail verification transition - Existing API keys will continue to work, new API keys will only work if verified') },
    { id: 'required_email', name: i18n.t('E-mail verification required - Existing API keys will break, only new API keys will work if verified') },
  ],

  passApiKeyOptions: [
    { id: 'header', name: i18n.t('Via HTTP header') },
    { id: 'param', name: i18n.t('Via GET query parameter') },
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
