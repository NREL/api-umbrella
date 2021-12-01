import { defaultStack } from '@pnotify/core';

import config from '../config/environment';

export function initialize() {
  if(config.integrationTestMode === true) {
    // Export the removeAll function as a global, for use in our test suite.
    window.PNotifyRemoveAll = function() {
      defaultStack.close();
    }
  }
}

export default {
  name: 'test-pnotify',
  initialize,
};
