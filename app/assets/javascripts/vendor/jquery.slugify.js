(function ($) {

	$.fn.slugify = function (source, options) {
		var $target = this;
		var $source = $(source);

		var settings = $.extend({
			slugFunc: (function (val, originalFunc) { return originalFunc(val); })
		}, options);


		var convertToSlug = function(val) {
			return settings.slugFunc(val, 
				(function(v) {
					if (!v) return '';
                                        var from = "ıİöÖüÜçÇğĞşŞâÂêÊîÎôÔûÛ";
					var to   = "iIoOuUcCgGsSaAeEiIoOuU";
					
					for (var i=0, l=from.length ; i<l ; i++) {
					    v = v.replace(new RegExp(from.charAt(i), 'g'), to.charAt(i));
					}

					return v.replace(/'/g, '').replace(/\s*&\s*/g, ' and ').replace(/[^A-Za-z0-9]+/g, '-').replace(/^-|-$/g, '').toLowerCase();
				})  
			);
		}

		var setLock = function () {
			if($target.val() != null && $target.val() != '') {
				$target.addClass('slugify-locked');
			} else {
				$target.removeClass('slugify-locked');
			}
		}

		var updateSlug = function () {
			var slug = convertToSlug($(this).val());
			$target.filter(':not(.slugify-locked)').val(slug).text(slug);		
		}


		$source.keyup( updateSlug ).change( updateSlug ); 

		$target.change(function () {       
			var slug = convertToSlug($(this).val());
			$target.val(slug).text(slug);
			setLock();
		});   

		setLock();         

		return this; 
	};
    
})(jQuery);             