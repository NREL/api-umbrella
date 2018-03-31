import Component from '@ember/component';
import { computed } from '@ember/object';

export default Component.extend({
  breadcrumbLinks: computed('breadcrumbs', function() {
    let crumbs = [];

    let data = this.get('breadcrumbs');
    for(let i = 0; i < data.length; i++) {
      let crumb = { name: data[i].crumb };
      if(i < data.length - 1) {
        crumb.prefix = data[i].prefix;
      }

      crumbs.push(crumb);
    }

    if(crumbs.length <= 1) {
      crumbs = [];
    }

    return crumbs;
  }),
});
