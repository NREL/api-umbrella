// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import { tagName } from "@ember-decorators/component";
import bootbox from 'bootbox';
import classic from 'ember-classic-decorator';
import without from 'lodash-es/without';

@tagName("")
@classic
export default class ServerTable extends Component {
  @service store;

  openModal = false;

  @action
  add() {
    this.set('serverModel', this.store.createRecord('api/server'));
    this.set('openModal', true);
  }

  @action
  edit(server) {
    this.set('serverModel', server);
    this.set('openModal', true);
  }

  @action
  remove(server) {
    bootbox.confirm('Are you sure you want to remove this server?', (response) => {
      if(response) {
        let collection = without(this.model.servers, server);
        this.model.set('servers', collection);
      }
    });
  }
}
