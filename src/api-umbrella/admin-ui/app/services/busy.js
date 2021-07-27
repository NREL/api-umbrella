import Evented from '@ember/object/evented';
import Service from '@ember/service';
import classic from 'ember-classic-decorator';

@classic
export default class BusyService extends Service.extend(Evented) {
  hide() {
    this.trigger('hide');
  }

  show(options) {
    this.trigger('show', options);
  }
}
