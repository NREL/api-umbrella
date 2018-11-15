export default {
  loading(button) {
    button.disabled = true;
    button.classList.add('btn-loading');
  },

  reset(button) {
    button.disabled = false;
    button.classList.remove('btn-loading');
  },
};
