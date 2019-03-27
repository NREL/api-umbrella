import escape from 'lodash-es/escape';
import isArray from 'lodash-es/isArray';
import map from 'lodash-es/map';
import moment from 'moment-timezone';

export default {
  renderEscaped(value, type) {
    if(type === 'display') {
      if(!value) {
        return '-';
      }

      return escape(value);
    }

    return value;
  },

  renderLink(options) {
    return function(value, type) {
      if(type === 'display') {
        if(!value) {
          return '-';
        }

        const link = options.editLink + encodeURIComponent(value.id) + '/edit';
        return '<a href="' + link + '">' + escape(value[options.nameField]) + '</a>';
      }

      return value;
    }
  },

  renderListEscaped(options) {
    return function(value, type) {
      if(type === 'display') {
        if(!value || value.length === 0) {
          return '-';
        }

        if(!isArray(value)) {
          value = [value];
        }

        return '<ul>' + map(value, function(v) { return '<li>' + escape(v[options.field]) + '</li>'; }).join('') + '</ul>';
      }

      return value;
    }
  },

  renderLinkedListEscaped(options) {
    return function(value, type) {
      if(type === 'display') {
        if(!value || value.length === 0) {
          return '-';
        }

        if(!isArray(value)) {
          value = [value];
        }

        return '<ul>' + map(value, function(v) {
          const link = options.editLink + encodeURIComponent(v.id) + '/edit';
          return '<li><a href="' + link + '">' + escape(v[options.nameField]) + '</a></li>';
        }).join('') + '</ul>';
      }

      return value;
    }
  },

  renderTime(value, type) {
    if(type === 'display' && value && value !== '-') {
      return moment(value).format('YYYY-MM-DD HH:mm:ss');
    }

    return value;
  },
};
