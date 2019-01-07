import Component from '@ember/component';
import { inject } from '@ember/service';
import { later } from '@ember/runloop';

const ANIMATION_DURATION = 300;
const DEFAULT_MESSAGE = 'Loading...';

export default Component.extend({
  busy: inject('busy'),

  classNames: ['busy-blocker'],
  animationElements: null,
  message: null,


  // Hooks
  // ------------------------
  didInsertElement() {
    // Convert animation duration ms to css string value
    let duration = (ANIMATION_DURATION / 1000) + 's';
    let busy = this.get('busy');

    // Hide immediately
    this.$().css('display', 'none');

    this.set('animationElements', this.$('.busy-blocker__bg, .busy-blocker__content'));
    // Set the animation duration on the backdrop element
    this.$('.busy-blocker__bg').css('animation-duration', duration);

    busy.on('hide', this, this._hide);
    busy.on('show', this, this._show);
  },

  willDestroyElement() {
    let busy = this.get('busy');

    busy.off('hide', this, this._hide);
    busy.off('show', this, this._show);
  },


  // Functions
  // ------------------------
  /**
   * Hide the busy animation.
   * @method _hide
   * @private
   * @return {void}
   */
  _hide() {
    let elements = this.get('animationElements');

    elements.removeClass('fade-in');
    elements.addClass('fade-out');

    later(this, function hideLoading() {
      this.$().css('display', 'none');
    }, ANIMATION_DURATION);
  },

  /**
   * Show the busy animation and apply received options.
   * @param  {Object} [options] An optional object containing options for the busy animation
   *                           such as a custom message.
   * @method _show
   * @private
   * @returns {void}
   */
  _show(options) {
    let elements = this.get('animationElements');
    let message = DEFAULT_MESSAGE;

    if(options && options.message) {
      message = options.message;
    }

    this.set('message', message);

    this.$().css('display', 'block');
    elements.removeClass('fade-out');
    elements.addClass('fade-in');
  },
});
