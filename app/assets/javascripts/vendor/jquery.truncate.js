(function ($) {
  'use strict';

  function findTruncPoint(dim, max, txt, start, end, $worker, token, reverse) {
    var makeContent = function (content) {
      $worker.text(content);
      $worker[reverse ? 'prepend' : 'append'](token);
    };

    var opt1, opt2, mid, opt1dim, opt2dim;

    if (reverse) {
      opt1 = start === 0 ? '' : txt.slice(-start);
      opt2 = txt.slice(-end);
    } else {
      opt1 = txt.slice(0, start);
      opt2 = txt.slice(0, end);
    }

    if (max < $worker.html(token)[dim]()) {
      return 0;
    }

    makeContent(opt2);
    opt1dim = $worker[dim]();
    makeContent(opt1);
    opt2dim = $worker[dim]();
    if (opt1dim < opt2dim) {
      return end;
    }

    mid = parseInt((start + end) / 2, 10);
    opt1 = reverse ? txt.slice(-mid) : txt.slice(0, mid);

    makeContent(opt1);
    if ($worker[dim]() === max) {
      return mid;
    }

    if ($worker[dim]() > max) {
      end = mid - 1;
    } else {
      start = mid + 1;
    }

    return findTruncPoint(dim, max, txt, start, end, $worker, token, reverse);
  }

  $.fn.truncate = function (options) {
    // backward compatibility
    if (options && !!options.center && !options.side) {
      options.side = 'center';
      delete options.center;
    }

    if (options && !(/^(left|right|center)$/).test(options.side)) {
      delete options.side;
    }

    var defaults = {
      width: 'auto',
      token: '&hellip;',
      side: 'right',
      addclass: false,
      addtitle: false,
      multiline: false,
      assumeSameStyle: false
    };
    options = $.extend(defaults, options);

    var fontCSS;
    var $element;
    var $truncateWorker;
    var elementText;
    
    if (options.assumeSameStyle) {
      $element = $(this[0]);
      fontCSS = {
        'fontFamily': $element.css('fontFamily'),
        'fontSize': $element.css('fontSize'),
        'fontStyle': $element.css('fontStyle'),
        'fontWeight': $element.css('fontWeight'),
        'font-variant': $element.css('font-variant'),
        'text-indent': $element.css('text-indent'),
        'text-transform': $element.css('text-transform'),
        'letter-spacing': $element.css('letter-spacing'),
        'word-spacing': $element.css('word-spacing'),
        'display': 'none'
      };
      $truncateWorker = $('<span/>')
                         .css(fontCSS)
                         .appendTo('body');
    }

    return this.each(function () {
      $element = $(this);
      elementText = $element.text();
      if (!options.assumeSameStyle) {
        fontCSS = {
          'fontFamily': $element.css('fontFamily'),
          'fontSize': $element.css('fontSize'),
          'fontStyle': $element.css('fontStyle'),
          'fontWeight': $element.css('fontWeight'),
          'font-variant': $element.css('font-variant'),
          'text-indent': $element.css('text-indent'),
          'text-transform': $element.css('text-transform'),
          'letter-spacing': $element.css('letter-spacing'),
          'word-spacing': $element.css('word-spacing'),
          'display': 'none'
        };
        $truncateWorker = $('<span/>')
                           .css(fontCSS)
                           .text(elementText)
                           .appendTo('body');
      } else {
        $truncateWorker.text(elementText);
      }
      
      var originalWidth = $truncateWorker.width();
      var truncateWidth = parseInt(options.width, 10) || $element.width();
      var dimension = 'width';
      var truncatedText, originalDim, truncateDim;

      if (options.multiline) {
        $truncateWorker.width($element.width());
        dimension = 'height';
        originalDim = $truncateWorker.height();
        truncateDim = $element.height() + 1;
      }
      else {
        originalDim = originalWidth;
        truncateDim = truncateWidth;
      }

      truncatedText = {before: '', after: ''};
      if (originalDim > truncateDim) {
        var truncPoint, truncPoint2;
        $truncateWorker.text('');

        if (options.side === 'left') {
          truncPoint = findTruncPoint(
            dimension, truncateDim, elementText, 0, elementText.length,
            $truncateWorker, options.token, true
          );
          truncatedText.after = elementText.slice(-1 * truncPoint);

        } else if (options.side === 'center') {
          truncateDim = parseInt(truncateDim / 2, 10) - 1;
          truncPoint = findTruncPoint(
            dimension, truncateDim, elementText, 0, elementText.length,
            $truncateWorker, options.token, false
          );
          truncPoint2 = findTruncPoint(
            dimension, truncateDim, elementText, 0, elementText.length,
            $truncateWorker, '', true
          );
          truncatedText.before = elementText.slice(0, truncPoint);
          truncatedText.after = elementText.slice(-1 * truncPoint2);

        } else if (options.side === 'right') {
          truncPoint = findTruncPoint(
            dimension, truncateDim, elementText, 0, elementText.length,
            $truncateWorker, options.token, false
          );
          truncatedText.before = elementText.slice(0, truncPoint);
        }

        if (options.addclass) {
          $element.addClass(options.addclass);
        }

        if (options.addtitle) {
          $element.attr('title', elementText);
        }

        truncatedText.before = $truncateWorker
                               .text(truncatedText
                                .before).html();
        truncatedText.after = $truncateWorker
                               .text(truncatedText.after)
                               .html();
        $element.empty().html(
          truncatedText.before + options.token + truncatedText.after
        );

      }

      if (!options.assumeSameStyle) {
        $truncateWorker.remove();
      }
    });
    
    if (options.assumeSameStyle) {
      $truncateWorker.remove();
    }
  };
})(jQuery);
