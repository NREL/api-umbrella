import Evented from '@ember/object/evented';
import Service from '@ember/service';

export default Service.extend(Evented, {
  hide() {
    this.trigger('hide');
  },

  show(options) {
    this.trigger('show', options);
  },
});
