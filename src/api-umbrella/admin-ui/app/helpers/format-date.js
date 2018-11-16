import { helper } from '@ember/component/helper';
import isString from 'lodash-es/isString';
import moment from 'moment-timezone';

export function formatDate(params) {
  let date = params[0];
  let format = params[1];

  if(!format || !isString(format)) {
    format = 'YYYY-MM-DD HH:mm Z';
  }

  if(date) {
    return moment(date).format(format);
  } else {
    return '';
  }
}

export default helper(formatDate);
