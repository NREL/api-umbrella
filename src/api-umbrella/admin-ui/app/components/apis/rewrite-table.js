// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import { reads } from '@ember/object/computed';
import { inject as service } from '@ember/service';
import { tagName } from '@ember-decorators/component';
// eslint-disable-next-line ember/no-mixins
import Sortable from 'api-umbrella-admin-ui/mixins/sortable';
import bootbox from 'bootbox';
import classic from 'ember-classic-decorator';

@classic
@tagName("")
export default class RewriteTable extends Component.extend(Sortable) {
  @service store;

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
