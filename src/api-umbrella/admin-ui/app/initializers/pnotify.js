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
