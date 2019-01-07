import { helper } from '@ember/component/helper';
import numeral from 'numeral';

export function formatNumber(params, args) {
  const number = params[0];
  const format = (args || {}).format;
  return numeral(number).format(format);
}

export default helper(formatNumber);
