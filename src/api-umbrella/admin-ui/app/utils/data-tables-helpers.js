import escape from 'lodash-es/escape';
import isArray from 'lodash-es/isArray';
import map from 'lodash-es/map';
import moment from 'moment-timezone';

export default {
  renderEscaped(value, type) {
    if(type === 'display' && value) {
      return escape(value);
    }

    return value;
  },

  renderListEscaped(value, type) {
    if(type === 'display' && value) {
      if(isArray(value)) {
        return map(value, function(v) { return escape(v); }).join('<br>');
      } else {
        return escape(value);
      }
    }

    return value;
  },

  renderTime(value, type) {
    if(type === 'display' && value && value !== '-') {
      return moment(value).format('YYYY-MM-DD HH:mm:ss');
    }

    return value;
  },
};
