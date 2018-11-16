import tippy from 'tippy.js'

export function initialize() {
  tippy('body', {
    target: 'button.tooltip-trigger',
    trigger: 'click',
    interactive: true,
    theme: 'light-border',
    arrow: true,
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
