module ApiUmbrellaTestHelpers
  module DateRangePicker
    def assert_date_range_picker(fragment_path)
      FactoryBot.create(:log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc)
      LogItem.gateway.refresh_index!

      admin_login

      # Set the browser's time to 2015-01-24T03:00:00Z.
      #
      # Since the analytics timezone for tests is set to America/Denver (in
      # config/test.yml), this time helps ensure the app takes into account the
      # analytics timezone for date calculations, since this corresponds to
      # 2015-01-23T20:00:00-07:00 (so the ending dates should all be 2015-01-23).
      #
      # Our usage of Zonebie to set a random local timezone for every test also
      # helps ensure all the client-side date logic is correct and we always use
      # the analytics timezone for date calculations, rather than the browser's
      # local time.
      page.execute_script("timekeeper.travel(Date.UTC(2015, 0, 24, 3, 0))")

      # Defaults to last 30 days.
      visit "/admin/##{fragment_path}"
      assert_download_csv_link_date_range("2014-12-25", "2015-01-23")
      assert_date_range_picker_date_range("Last 30 Days", "2014-12-25", "2015-01-23")
      assert_current_admin_url(fragment_path, nil)

      # Direct link to last 7 days.
      visit "/admin/##{fragment_path}?date_range=7d"
      assert_download_csv_link_date_range("2015-01-17", "2015-01-23")
      assert_date_range_picker_date_range("Last 7 Days", "2015-01-17", "2015-01-23")
      assert_current_admin_url(fragment_path, { "date_range" => "7d" })

      # Direct link to a custom date range.
      visit "/admin/##{fragment_path}?start_at=2015-01-19&end_at=2015-01-22"
      assert_download_csv_link_date_range("2015-01-19", "2015-01-22")
      assert_date_range_picker_date_range("Custom Range", "2015-01-19", "2015-01-22")
      assert_current_admin_url(fragment_path, {
        "start_at" => "2015-01-19",
        "end_at" => "2015-01-22",
      })

      # Direct link to a custom date range that corresponds with a predefined
      # range (last 7 days).
      visit "/admin/##{fragment_path}?start_at=2015-01-17&end_at=2015-01-23"
      assert_download_csv_link_date_range("2015-01-17", "2015-01-23")
      assert_date_range_picker_date_range("Last 7 Days", "2015-01-17", "2015-01-23")
      assert_current_admin_url(fragment_path, {
        "start_at" => "2015-01-17",
        "end_at" => "2015-01-23",
      })

      # Change to today in UI.
      change_date_picker("Today")
      assert_download_csv_link_date_range("2015-01-23", "2015-01-23")
      assert_date_range_picker_date_range("Today", "2015-01-23", "2015-01-23")
      assert_current_admin_url(fragment_path, { "date_range" => "today" })

      # Change to last 30 days in UI.
      change_date_picker("Last 30 Days")
      assert_download_csv_link_date_range("2014-12-25", "2015-01-23")
      assert_date_range_picker_date_range("Last 30 Days", "2014-12-25", "2015-01-23")
      assert_current_admin_url(fragment_path, nil)

      # Change to a custom range in UI.
      change_date_picker("Custom Range", "2014-12-31", "2015-01-23")
      assert_download_csv_link_date_range("2014-12-31", "2015-01-23")
      assert_date_range_picker_date_range("Custom Range", "2014-12-31", "2015-01-23")
      assert_current_admin_url(fragment_path, {
        "start_at" => "2014-12-31",
        "end_at" => "2015-01-23",
      })

      # Change to a custom range in UI that corresponds with a predefined range
      # (last 7 days).
      change_date_picker("Custom Range", "2015-01-17", "2015-01-23")
      assert_download_csv_link_date_range("2015-01-17", "2015-01-23")
      assert_date_range_picker_date_range("Last 7 Days", "2015-01-17", "2015-01-23")
      assert_current_admin_url(fragment_path, {
        "start_at" => "2015-01-17",
        "end_at" => "2015-01-23",
      })

      # Change back to predefined range in UI.
      change_date_picker("Last 7 Days")
      assert_download_csv_link_date_range("2015-01-17", "2015-01-23")
      assert_date_range_picker_date_range("Last 7 Days", "2015-01-17", "2015-01-23")
      assert_current_admin_url(fragment_path, {
        "date_range" => "7d",
      })

      # Change the browser's time during the current session.
      assert_text("Filter Results")
      visit "/admin/#/"
      refute_text("Filter Results")
      page.execute_script("timekeeper.travel(Date.UTC(2015, 0, 26, 3, 0))")

      # Check that a relative URL works with the updated data.
      visit "/admin/##{fragment_path}?date_range=7d"
      assert_download_csv_link_date_range("2015-01-19", "2015-01-25")
      assert_date_range_picker_date_range("Last 7 Days", "2015-01-19", "2015-01-25")
      assert_current_admin_url(fragment_path, { "date_range" => "7d" })

      # Check that static dates remain the same.
      visit "/admin/##{fragment_path}?start_at=2015-01-17&end_at=2015-01-23"
      assert_download_csv_link_date_range("2015-01-17", "2015-01-23")
      assert_date_range_picker_date_range("Custom Range", "2015-01-17", "2015-01-23")
      assert_current_admin_url(fragment_path, {
        "start_at" => "2015-01-17",
        "end_at" => "2015-01-23",
      })
    ensure
      page.execute_script("timekeeper.reset()")
    end

    def assert_download_csv_link_date_range(start_at, end_at)
      assert_link("Download CSV", :href => /start_at=#{start_at}/)
      link = find_link("Download CSV")
      uri = Addressable::URI.parse(link[:href])
      assert_equal(start_at, uri.query_values["start_at"])
      assert_equal(end_at, uri.query_values["end_at"])
      assert_nil(uri.query_values["date_range"])
    end

    def assert_date_range_picker_date_range(range_label, start_at, end_at)
      start_at = Date.parse(start_at)
      end_at = Date.parse(end_at)

      assert_text("#{start_at.strftime("%b %e, %Y")} - #{end_at.strftime("%b %e, %Y")}")
      find("#reportrange a").click
      assert_selector(".daterangepicker")
      within(".daterangepicker") do
        assert_selector(".ranges li.active", :text => range_label)
        if(range_label == "Custom Range")
          assert_selector(".calendar", :visible => :visible)
          assert_field("daterangepicker_start", :with => start_at.strftime("%m/%d/%Y"))
          assert_field("daterangepicker_end", :with => end_at.strftime("%m/%d/%Y"))
        else
          assert_selector(".calendar", :visible => :hidden)
        end
        click_button("Cancel")
      end
      refute_selector(".daterangepicker")
    end

    def change_date_picker(range_label, start_at = nil, end_at = nil)
      find("#reportrange a").click
      within(".daterangepicker") do
        find("li", :text => range_label).click
        if(range_label == "Custom Range")
          start_at = Date.parse(start_at)
          end_at = Date.parse(end_at)

          fill_in("daterangepicker_start", :with => start_at.strftime("%m/%d/%Y"))
          fill_in("daterangepicker_end", :with => end_at.strftime("%m/%d/%Y"))
          click_button("Apply")
        end
      end
    end
  end
end
