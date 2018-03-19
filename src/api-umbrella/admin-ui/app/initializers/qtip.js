import $ from 'jquery';

export function initialize() {
  $(document).on('click', 'a[rel=tooltip]', function(event) {
    $(this).qtip({
      overwrite: false,
      show: {
        event: event.type,
        ready: true,
        solo: true,
      },
      hide: {
        event: 'unfocus',
      },
      style: {
        classes: 'qtip-bootstrap ' + $(this).data('tooltip-class'),
      },
      position: {
        viewport: true,
        my: 'bottom left',
        at: 'top center',
        adjust: {
          y: 2,
        },
      },
    }, event);

    event.preventDefault();
  });

  $(document).on('click', 'a[rel=popover]', function(event) {
    $(this).qtip({
      overwrite: false,
      show: {
        event: event.type,
        ready: true,
        solo: true,
      },
      hide: {
        event: 'unfocus',
      },
      content: {
        text(event) {
          let target = $(event.target).attr('href');
          let content = $(target).html();
          return content;
        },
      },
      style: {
        classes: 'qtip-bootstrap qtip-wide ' + $(this).data('tooltip-class'),
      },
      position: {
        viewport: false,
        my: 'top left',
        at: 'bottom center',
        adjust: {
          y: 2,
        },
      },
    }, event);

    event.preventDefault();
  });
}

export default {
  name: 'qtip',
  initialize,
};
