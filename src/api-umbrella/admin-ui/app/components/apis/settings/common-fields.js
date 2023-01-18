// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { tagName } from "@ember-decorators/component";
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import classic from 'ember-classic-decorator';

@tagName("")
@classic
export default class CommonFields extends Component {
  requireHttpsOptions = [
    { id: null, name: t('Inherit (default - required)') },
    { id: 'required_return_error', name: t('Required - HTTP requests will receive a message to use HTTPS') },
    { id: 'transition_return_error', name: t('Transitionary - Optional for existing API keys, required for new API keys') },
    { id: 'optional', name: t('Optional - HTTPS is optional') },
  ];

  disableApiKeyOptions = [
    { id: null, name: t('Inherit (default - required)') },
    { id: false, name: t('Required - API keys are mandatory') },
    { id: true, name: t('Disabled - API keys are optional') },
  ];

  apiKeyVerificationLevelOptions = [
    { id: null, name: t('Inherit (default - none)') },
    { id: 'none', name: t('None - API keys can be used without any verification') },
    { id: 'transition_email', name: t('E-mail verification transition - Existing API keys will continue to work, new API keys will only work if verified') },
    { id: 'required_email', name: t('E-mail verification required - Existing API keys will break, only new API keys will work if verified') },
  ];

  passApiKeyOptions = [
    { id: 'header', name: t('Via HTTP header') },
    { id: 'param', name: t('Via GET query parameter') },
  ];

  anonymousRateLimitBehaviorOptions = [
    { id: 'ip_fallback', name: 'IP Fallback - API key rate limits are applied as IP limits' },
    { id: 'ip_only', name: 'IP Only - API key rate limits are ignored (only IP based limits are applied)' },
  ];

  authenticatedRateLimitBehaviorOptions = [
    { id: 'all', name: 'All Limits - Both API key rate limits and IP based limits are applied' },
    { id: 'api_key_only', name: 'API Key Only - IP based rate limits are ignored (only API key limits are applied)' },
  ];
}
