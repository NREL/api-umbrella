module ApiUmbrellaTestHelpers
  module CapybaraCustomBootstrapInputs
    # For our custom radio/checkboxes, we need to click on the label, rather
    # than the input (since the input is technically hidden and only virtually
    # shown). The "automatic_label_click" option makes this work in most cases,
    # so we can use the default "check" and "uncheck" helpers", however for our
    # "User agrees to the terms and conditions" checkbox, this doesn't work,
    # since that label also has a link tag embedded inside, so clicking on the
    # center of the label ends up triggering the popup, rather than the
    # checkbox checking/unchecking.
    #
    # So these batch of label helpers are for cases where we know we need to
    # click directly on the label, and they also accept ":click" options that
    # are passed along to the label click for controlling it's position.
    #
    # Should be identical to the existing implementation, except that it
    # accepts the click options, and we don't bother trying to click on the
    # checkbox/radio first:
    # https://github.com/teamcapybara/capybara/blob/3.10.1/lib/capybara/node/actions.rb#L323
    def label_check(locator = nil, **options)
      _custom_check_with_label(:checkbox, true, locator, **options)
    end

    def _custom_check_with_label(selector, checked, locator, **options)
      # Change so the click is from the top-left coordinates instead of center.
      original_w3c_click_offset = Capybara.w3c_click_offset
      Capybara.w3c_click_offset = false

      options[:allow_self] = true if locator.nil?
      click_options = options.delete(:click) || { :x => 1, :y => 1 }

      el = find(selector, locator, **options.merge(:visible => :all))
      el.session.find(:label, :for => el, :visible => true).click(**click_options) unless el.checked? == checked
    ensure
      Capybara.w3c_click_offset = original_w3c_click_offset
    end

    def custom_input_trigger_click(input)
      # Ensure there's a label for the custom checkbox or radio styling.
      label = find(:label, :for => input, :visible => true)
      assert(label.text)

      id = input[:id]
      assert(id)
      page.execute_script("document.getElementById('#{id}').click()")
    end
  end
end
