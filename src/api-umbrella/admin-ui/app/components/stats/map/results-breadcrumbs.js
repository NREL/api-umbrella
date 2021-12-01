// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { computed } from '@ember/object';
import { tagName } from "@ember-decorators/component";
import classic from 'ember-classic-decorator';

@tagName("")
@classic
export default class ResultsBreadcrumbs extends Component {
  @computed('breadcrumbs')
  get breadcrumbLinks() {
    let crumbs = [];

    let data = this.breadcrumbs;
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
  }
}
