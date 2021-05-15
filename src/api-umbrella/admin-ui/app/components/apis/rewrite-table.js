import classic from 'ember-classic-decorator';
import { action } from '@ember/object';
import { tagName } from '@ember-decorators/component';
import { inject } from '@ember/service';
import { reads } from '@ember/object/computed';
// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
// eslint-disable-next-line ember/no-mixins
import Sortable from 'api-umbrella-admin-ui/mixins/sortable';
import bootbox from 'bootbox';

// eslint-disable-next-line ember/no-classic-classes
@classic
@tagName("")
export default class RewriteTable extends Component.extend(Sortable) {
  @inject()
  store;

  openModal = false;

  @reads('model.rewrites')
  sortableCollection;

  @action
  add() {
    this.set('rewriteModel', this.store.createRecord('api/rewrite'));
    this.set('openModal', true);
  }

  @action
  edit(rewrite) {
    this.set('rewriteModel', rewrite);
    this.set('openModal', true);
  }

  @action
  remove(rewrite) {
    bootbox.confirm('Are you sure you want to remove this rewrite?', function(response) {
      if(response) {
        this.model.rewrites.removeObject(rewrite);
      }
    }.bind(this));
  }
}
