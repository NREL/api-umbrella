import PNotify from 'pnotify';
import config from '../config/environment';

export function initialize() {
  if(config.integrationTestMode === true) {
    // Export the removeAll function as a global, for use in our test suite.
    window.PNotifyRemoveAll = PNotify.removeAll;
  }
}

export default {
  name: 'test-pnotify',
  initialize,
};
