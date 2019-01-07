import config from '../config/environment';
import timekeeper from 'timekeeper';

export function initialize() {
  if(config.integrationTestMode === true) {
    window.timekeeper = timekeeper;
  }
}

export default {
  name: 'test-timekeeper',
  initialize,
};
