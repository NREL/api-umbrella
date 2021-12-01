import { helper } from '@ember/component/helper';
import { assign } from '@ember/polyfills';
import I18n from 'i18n-js';

export function t(params, options) {
  let key = params[0];
  // The options is an EmptyObject instance, which doesn't respond to
  // hasOwnProperty as I18n.t expects.
  // https://github.com/emberjs/ember.js/issues/14668
  const plainOptions = assign({}, options);
  return I18n.t(key, plainOptions);
}

export default helper(t);
