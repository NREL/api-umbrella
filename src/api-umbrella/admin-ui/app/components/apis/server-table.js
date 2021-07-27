// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import { inject } from '@ember/service';
import { tagName } from "@ember-decorators/component";
import bootbox from 'bootbox';
import classic from 'ember-classic-decorator';

@tagName("")
@classic
export default class ServerTable extends Component {
  @inject()
  store;

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
    bootbox.confirm('Are you sure you want to remove this server?', function(response) {
      if(response) {
        this.model.servers.removeObject(server);
      }
    }.bind(this));
  }
}
