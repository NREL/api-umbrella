module ApiUmbrellaTestHelpers
  module CapybaraCodemirror
    def fill_in_codemirror(locator, options = {})
      field = find_field(locator, :visible => :all)

      # Click on the label to force the codemirror input to focus. Otherwise,
      # the input field is invisible and text can't be entered until this focus
      # happens.
      label = find(:label, :for => field)
      label.click

      fill_in(locator, **options.merge(:visible => :all))
    end

    def assert_codemirror_field(locator, options = {})
      field = find_field(locator, :visible => :all)

      # Verify that the displayed text by code mirror contains the expected
      # value, along with the expected line numbers.
      expected_value = options.fetch(:with)
      expected_text = expected_value.split("\n").map.with_index(1) do |line_value, line_num|
        "#{line_num}\n#{line_value}"
      end.join("\n")
      assert_selector("##{field["data-codemirror-wrapper-element-id"]}", :text => expected_text)

      # Verify that the hidden original textarea contains the expected value.
      assert_equal(expected_value, find_by_id(field["data-codemirror-original-textarea-id"], :visible => :all).value)
    end
  end
end
