$(document).ready(function() {
  $('.image-link').magnificPopup({ 
    type: 'image',
    image: {
      cursor: null,
      verticalFit: false,
    },
    retina: {
      ratio: 2,
      replaceSrc: function(item, ratio) {
        return $(item.el).find('img').data('at2x');
      }
    }
  });

  $('.image-link-no2x').magnificPopup({ 
    type: 'image',
    image: {
      cursor: null,
      verticalFit: false,
    }
  });
});
