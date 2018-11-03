import { helper } from '@ember/component/helper';
import numeral from 'numeral';

export function formatNumber([number, ...rest], args) {
  const format = (args || {}).format;
  return numeral(number).format(format);
}

export default helper(formatNumber);
