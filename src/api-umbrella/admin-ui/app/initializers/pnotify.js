import 'npm:pnotify/dist/pnotify.buttons';
import 'npm:pnotify/dist/pnotify.mobile';

import PNotify from 'npm:pnotify';

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

  // Export the removeAll function as a global, for use in our test suite.
  window.PNotifyRemoveAll = PNotify.removeAll;
}

export default {
  name: 'pnotify',
  initialize,
};
