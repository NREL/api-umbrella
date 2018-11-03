import Service from '@ember/service';
import Evented from '@ember/object/evented';

export default Service.extend(Evented, {
  hide() {
    this.trigger('hide');
  },

  show(options) {
    this.trigger('show', options);
  }
});
