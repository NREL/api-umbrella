export function initialize() {
  _.merge(PNotify.prototype.options, {
    styling: 'bootstrap2',
    width: '400px',
    icon: false,
    animate_speed: 'fast',
    history: {
      history: false
    },
    buttons: {
      sticker: false
    }
  });
}

export default {
  name: 'pnotify',
  initialize
};
