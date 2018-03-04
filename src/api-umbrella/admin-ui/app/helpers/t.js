import I18n from 'npm:i18n-js';
import { helper } from '@ember/component/helper';
import { merge } from '@ember/polyfills';

export function t(params, options) {
  let key = params[0];
  // The options is an EmptyObject instance, which doesn't respond to
  // hasOwnProperty as I18n.t expects.
  // https://github.com/emberjs/ember.js/issues/14668
  const plainOptions = merge({}, options);
  return I18n.t(key, plainOptions);
}

export default helper(t);
