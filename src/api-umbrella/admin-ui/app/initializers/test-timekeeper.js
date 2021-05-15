import timekeeper from 'timekeeper';

import config from '../config/environment';

export function initialize() {
  if(config.integrationTestMode === true) {
    window.timekeeper = timekeeper;
  }
}

export default {
  name: 'test-timekeeper',
  initialize,
};
