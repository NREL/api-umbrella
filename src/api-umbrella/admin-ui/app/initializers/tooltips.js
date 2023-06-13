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
      } else {
        // By default tippy won't change the content if the
        // `data-tippy-content` attribute changes, but we have some cases where
        // this needs to be handled (eg, the analytics query form).
        const content = tip.reference.dataset.tippyContent;
        if(content) {
          tip.setContent(content);
        }
      }
    },
  });
}

export default {
  name: 'tooltips',
  initialize,
};
