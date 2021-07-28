// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { later } from '@ember/runloop';
import { inject } from '@ember/service';
import classic from 'ember-classic-decorator';
import $ from 'jquery';

const ANIMATION_DURATION = 300;
const DEFAULT_MESSAGE = 'Loading...';

@classic
export default class BusyBlocker extends Component {
  tagName = '';

  @inject('busy')
  busy;

  animationElements = null;
  message = null;

  // Hooks
  // ------------------------
  didInsert() {
    // Convert animation duration ms to css string value
    let duration = (ANIMATION_DURATION / 1000) + 's';
    let busy = this.busy;

    // Hide immediately
    $(this.element).css('display', 'none');

    this.set('animationElements', $(this.element).find('.busy-blocker__bg, .busy-blocker__content'));
    // Set the animation duration on the backdrop element
    $(this.element).find('.busy-blocker__bg').css('animation-duration', duration);

    busy.on('hide', this, this._hide);
    busy.on('show', this, this._show);
  }

  willDestroyNode() {
    let busy = this.busy;

    busy.off('hide', this, this._hide);
    busy.off('show', this, this._show);
  }

  // Functions
  // ------------------------
  /**
   * Hide the busy animation.
   * @method _hide
   * @private
   * @return {void}
   */
  _hide() {
    let elements = this.animationElements;

    elements.removeClass('fade-in');
    elements.addClass('fade-out');

    later(this, function hideLoading() {
      $(this.element).css('display', 'none');
    }, ANIMATION_DURATION);
  }

  /**
   * Show the busy animation and apply received options.
   * @param  {Object} [options] An optional object containing options for the busy animation
   *                           such as a custom message.
   * @method _show
   * @private
   * @returns {void}
   */
  _show(options) {
    let elements = this.animationElements;
    let message = DEFAULT_MESSAGE;

    if(options && options.message) {
      message = options.message;
    }

    this.set('message', message);

    $(this.element).css('display', 'block');
    elements.removeClass('fade-out');
    elements.addClass('fade-in');
  }
}
