module ApiUmbrellaTestHelpers
  module CapybaraSelectize
    def selectize_add(locator, value)
      fill_in locator, :with => value
      within page.document do
        assert_selector(".selectize-dropdown > .selectize-dropdown-content")
        find(".selectize-dropdown-content div.create", :text => /Add #{value}/).click
      end
      find_field(locator).send_keys(:escape)
      within page.document do
        refute_selector(".selectize-dropdown")
      end
    end

    def selectize_remove(locator, value)
      field = find_field(locator)
      find("##{field["data-selectize-control-id"]} [data-value='#{value}'] .remove").click
    end

    def assert_selectize_field(locator, options = {})
      field = find_field(locator)

      # Verify the displayed text matches the expected values (accounting for
      # the "x" remove buttons in the displayed version).
      expected_value = options.fetch(:with)
      expected_text = expected_value.split(",").map { |value| "#{value}\n×" }.join("\n")
      assert_selector("##{field["data-selectize-control-id"]}", :text => expected_text)

      # Verify that the original hidden input matches the expected value.
      assert_equal(expected_value, find_by_id(field["data-raw-input-id"], :visible => :all).value)
    end
  end
end
