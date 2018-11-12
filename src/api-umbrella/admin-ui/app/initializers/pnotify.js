import 'pnotify/lib/es/PNotifyButtons';
import 'pnotify/lib/es/PNotifyMobile';
import PNotify from 'pnotify';

export function initialize() {
  PNotify.defaults.styling = 'bootstrap4';
  PNotify.defaults.width = '400px';
  PNotify.defaults.icon = false;
  PNotify.defaults.icons = 'fontawesome5'; // Icons used for Buttons plugin.
  PNotify.defaults.animation = 'none';
  PNotify.modules.Buttons.defaults.sticker = false;
}

export default {
  name: 'pnotify',
  initialize,
};
