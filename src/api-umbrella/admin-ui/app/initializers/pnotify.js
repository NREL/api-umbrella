import PNotify from 'npm:pnotify';
import 'npm:pnotify/dist/pnotify.buttons';
import 'npm:pnotify/dist/pnotify.mobile';

export function initialize() {
  _.merge(PNotify.prototype.options, {
    styling: 'bootstrap3',
    width: '400px',
    icon: false,
    animation: 'none',
    history: {
      history: false,
    },
    buttons: {
      sticker: false,
    },
  });
}

export default {
  name: 'pnotify',
  initialize,
};
