import Ember from 'ember';

export default Ember.Component.extend({
  breadcrumbLinks: Ember.computed('breadcrumbs', function() {
    let crumbs = [];

    let data = this.get('breadcrumbs');
    for(let i = 0; i < data.length; i++) {
      let crumb = { name: data[i].name };
      if(i < data.length - 1) {
        crumb.region = data[i].region;
      }

      crumbs.push(crumb);
    }

    if(crumbs.length <= 1) {
      crumbs = [];
    }

    return crumbs;
  }),
});
