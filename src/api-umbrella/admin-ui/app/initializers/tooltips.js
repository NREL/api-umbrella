import { delegate } from 'tippy.js';

export function initialize() {
  delegate('body', {
    target: 'button.tooltip-trigger',
    trigger: 'click',
    interactive: true,
    theme: 'light-border',
    arrow: true,
    allowHTML: true,
    onShow: (tip) => {
      const contentSelector = tip.reference.getAttribute('data-tooltip-content-selector');
      if(contentSelector) {
        const contentElement = document.querySelector(contentSelector);
        tip.setContent(contentElement.innerHTML);
      }
    },
  });
}

export default {
  name: 'tooltips',
  initialize,
};
