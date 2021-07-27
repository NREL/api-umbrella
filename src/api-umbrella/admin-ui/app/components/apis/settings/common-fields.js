// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { tagName } from "@ember-decorators/component";
import classic from 'ember-classic-decorator';
import I18n from 'i18n-js';

@tagName("")
@classic
export default class CommonFields extends Component {
  init() {
    super.init(...arguments);

    this.requireHttpsOptions = [
      { id: null, name: I18n.t('admin.api.settings.require_https_options.inherit') },
      { id: 'required_return_error', name: I18n.t('admin.api.settings.require_https_options.required_return_error') },
      { id: 'transition_return_error', name: I18n.t('admin.api.settings.require_https_options.transition_return_error') },
      { id: 'optional', name: I18n.t('admin.api.settings.require_https_options.optional') },
    ];

    this.disableApiKeyOptions = [
      { id: null, name: I18n.t('admin.api.settings.disable_api_key_options.inherit') },
      { id: false, name: I18n.t('admin.api.settings.disable_api_key_options.required') },
      { id: true, name: I18n.t('admin.api.settings.disable_api_key_options.disabled') },
    ];

    this.apiKeyVerificationLevelOptions = [
      { id: null, name: I18n.t('admin.api.settings.api_key_verification_level_options.inherit') },
      { id: 'none', name: I18n.t('admin.api.settings.api_key_verification_level_options.none') },
      { id: 'transition_email', name: I18n.t('admin.api.settings.api_key_verification_level_options.transition_email') },
      { id: 'required_email', name: I18n.t('admin.api.settings.api_key_verification_level_options.required_email') },
    ];

    this.passApiKeyOptions = [
      { id: 'header', name: I18n.t('admin.api.settings.pass_api_key_header') },
      { id: 'param', name: I18n.t('admin.api.settings.pass_api_key_param') },
    ];

    this.anonymousRateLimitBehaviorOptions = [
      { id: 'ip_fallback', name: 'IP Fallback - API key rate limits are applied as IP limits' },
      { id: 'ip_only', name: 'IP Only - API key rate limits are ignored (only IP based limits are applied)' },
    ];

    this.authenticatedRateLimitBehaviorOptions = [
      { id: 'all', name: 'All Limits - Both API key rate limits and IP based limits are applied' },
      { id: 'api_key_only', name: 'API Key Only - IP based rate limits are ignored (only API key limits are applied)' },
    ];
  }
}
