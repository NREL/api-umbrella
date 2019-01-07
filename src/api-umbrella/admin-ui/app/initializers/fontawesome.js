import { dom } from '@fortawesome/fontawesome-svg-core';

export function initialize() {
  dom.watch();
}

export default {
  name: 'fontawesome',
  initialize,
};
