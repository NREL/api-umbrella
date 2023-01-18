require "support/api_umbrella_test_helpers/admin_auth"

module ApiUmbrellaSharedTests
  module DataTablesApi
    include ApiUmbrellaTestHelpers::AdminAuth

    def test_paginate_results
      FactoryBot.create_list(data_tables_factory_name, 11)

      http_opts = http_options.deep_merge(admin_token)

      record_count = data_tables_record_count
      assert_operator(record_count, :>, 10)

      page1_response = Typhoeus.get(data_tables_api_url, http_opts.deep_merge({
        :params => {
          :length => 2,
        },
      }))
      assert_response_code(200, page1_response)
      page1_data = MultiJson.load(page1_response.body)
      assert_data_tables_root_fields(page1_data)
      assert_equal(record_count, page1_data.fetch("recordsTotal"))
      assert_equal(record_count, page1_data.fetch("recordsFiltered"))
      assert_equal(2, page1_data.fetch("data").length)

      page2_response = Typhoeus.get(data_tables_api_url, http_opts.deep_merge({
        :params => {
          :length => 2,
          :start => 2,
        },
      }))
      assert_response_code(200, page2_response)
      page2_data = MultiJson.load(page2_response.body)
      assert_data_tables_root_fields(page2_data)
      assert_equal(record_count, page2_data.fetch("recordsTotal"))
      assert_equal(record_count, page2_data.fetch("recordsFiltered"))
      assert_equal(2, page2_data.fetch("data").length)

      page1_ids = page1_data.fetch("data").map { |r| r.fetch("id") }
      page2_ids = page2_data.fetch("data").map { |r| r.fetch("id") }
      assert_equal(2, page1_ids.length)
      assert_equal(2, page2_ids.length)
      assert(page1_ids.first)
      assert(page2_ids.first)
      assert_equal([], page1_ids & page2_ids)
    end

    def test_no_default_limit
      FactoryBot.create_list(data_tables_factory_name, 101)

      http_opts = http_options.deep_merge(admin_token)

      record_count = data_tables_record_count
      assert_operator(record_count, :>, 100)

      response = Typhoeus.get(data_tables_api_url, http_opts)
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal(record_count, data.fetch("recordsTotal"))
      assert_equal(record_count, data.fetch("recordsFiltered"))
      assert_equal(record_count, data.fetch("data").length)
    end

    def test_multiple_cursor_fetches
      FactoryBot.create_list(data_tables_factory_name, 1005)

      http_opts = http_options.deep_merge(admin_token)

      record_count = data_tables_record_count
      assert_operator(record_count, :>=, 1005)

      response = Typhoeus.get(data_tables_api_url, http_opts)
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal(record_count, data.fetch("recordsTotal"))
      assert_equal(record_count, data.fetch("recordsFiltered"))
      assert_equal(record_count, data.fetch("data").length)
    end

    def test_empty_result
      response = Typhoeus.get(data_tables_api_url, http_options.deep_merge(admin_token).deep_merge({
        :params => {
          # Search for value that will never be found.
          :search => { :value => "#{SecureRandom.uuid}#{SecureRandom.uuid}" },
        },
      }))
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_data_tables_root_fields(data)

      assert_equal(0, data.fetch("draw"))
      assert_equal(0, data.fetch("recordsTotal"))
      assert_equal(0, data.fetch("recordsFiltered"))
      assert_kind_of(Array, data.fetch("data"))
      assert_equal(0, data.fetch("data").length)
    end

    def test_search_id
      id = SecureRandom.uuid
      assert_data_tables_search(:id, id, id)
    end

    def test_order_created_at
      assert_data_tables_order(:created_at, [Time.utc(2017, 1, 1), Time.utc(2017, 1, 2)])
    end

    def test_order_updated_at
      assert_data_tables_order(:updated_at, [Time.utc(2017, 1, 1), Time.utc(2017, 1, 2)])
    end

    def test_order_multiple
      records = [
        FactoryBot.create(data_tables_factory_name, :created_at => Time.utc(2017, 1, 1), :updated_at => Time.utc(2017, 1, 2)),
        FactoryBot.create(data_tables_factory_name, :created_at => Time.utc(2017, 1, 1), :updated_at => Time.utc(2017, 1, 3)),
        FactoryBot.create(data_tables_factory_name, :created_at => Time.utc(2017, 1, 2), :updated_at => Time.utc(2017, 1, 3)),
        FactoryBot.create(data_tables_factory_name, :created_at => Time.utc(2017, 1, 3), :updated_at => Time.utc(2017, 1, 3)),
      ]

      ordered_ids = response_order({
        :created_at => "asc",
        :updated_at => "asc",
      }, records)
      assert_equal([
        records[0].id,
        records[1].id,
        records[2].id,
        records[3].id,
      ], ordered_ids)

      ordered_ids = response_order({
        :created_at => "desc",
        :updated_at => "desc",
      }, records)
      assert_equal([
        records[3].id,
        records[2].id,
        records[1].id,
        records[0].id,
      ], ordered_ids)

      ordered_ids = response_order({
        :created_at => "desc",
        :updated_at => "asc",
      }, records)
      assert_equal([
        records[3].id,
        records[2].id,
        records[0].id,
        records[1].id,
      ], ordered_ids)
    end

    private

    def data_tables_api_url
      raise NotImplementedError.new("#{self.class} must implement '#{__method__}'")
    end

    def data_tables_factory_name
      raise NotImplementedError.new("#{self.class} must implement '#{__method__}'")
    end

    def data_tables_record_count
      raise NotImplementedError.new("#{self.class} must implement '#{__method__}'")
    end

    def assert_data_tables_root_fields(data)
      assert_kind_of(Hash, data)
      assert_equal([
        "data",
        "draw",
        "recordsFiltered",
        "recordsTotal",
      ].sort, data.keys.sort)

      assert_kind_of(Array, data.fetch("data"))
      assert_kind_of(Integer, data.fetch("draw"))
      assert_kind_of(Integer, data.fetch("recordsFiltered"))
      assert_kind_of(Integer, data.fetch("recordsTotal"))
    end

    def assert_data_tables_search(field, value, search)
      record = FactoryBot.create(data_tables_factory_name, field => value)

      # Ensure the search value (which should represent a wildcard search) can
      # be found in a case insensitive manner.
      assert_wildcard_search_match(field, value, search, record)
      assert_wildcard_search_match(field, value, search.downcase, record)
      assert_wildcard_search_match(field, value, search.upcase, record)

      # Ensure the full value can be found.
      first_value = if(value.kind_of?(Array)) then value.first else value end
      unless first_value.kind_of?(ActiveRecord::Base)
        assert_wildcard_search_match(field, value, first_value, record)
      end

      # Ensure that extra characters surrounding the search lead to no results.
      # Notably, these extra characters also check to ensure we're escaping
      # special characters in the search.
      [
        # SQL "LIKE" escaping.
        "%",
        "_",
        "\\",
        # Regex escaping.
        "*",
        ".",
      ].each do |extra|
        refute_wildcard_search_match(field, value, "#{search}#{extra}")
        refute_wildcard_search_match(field, value, "#{extra}#{search}")
      end
    end

    def assert_wildcard_search_match(field, value, search, record)
      response = Typhoeus.get(data_tables_api_url, http_options.deep_merge(admin_token).deep_merge({
        :params => {
          :search => { :value => search },
        },
      }))
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal(1, data.fetch("recordsTotal"))
      assert_equal(1, data.fetch("data").length)
      assert_equal(record.id, data.fetch("data").first.fetch("id"))
    end

    def refute_wildcard_search_match(field, value, search)
      response = Typhoeus.get(data_tables_api_url, http_options.deep_merge(admin_token).deep_merge({
        :params => {
          :search => { :value => search },
        },
      }))
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal(0, data.fetch("recordsTotal"))
      assert_equal(0, data.fetch("data").length)
    end

    def assert_data_tables_order(field, values)
      assert_equal(2, values.length)
      records = values.sort.map do |value|
        FactoryBot.create(data_tables_factory_name, field => value)
      end

      # Test that ascending order is default if no explicit order is given.
      ordered_ids = response_order({ field => nil }, records)
      assert_equal([records[0].id, records[1].id], ordered_ids)

      ordered_ids = response_order({ field => "asc" }, records)
      assert_equal([records[0].id, records[1].id], ordered_ids)

      ordered_ids = response_order({ field => "desc" }, records)
      assert_equal([records[1].id, records[0].id], ordered_ids)
    end

    def response_order(field_orders, records)
      params = {
        :columns => {},
        :order => {},
      }
      field_orders.each_with_index do |(field, order), index|
        params[:columns][index] = { :data => field }

        # Set the order indexes to 2, 12, etc. This helps test to ensure that
        # we're sorting the order indexes base on integer value (so 2 < 12),
        # and not string value (where "12" < "2").
        order_index = (index * 10) + 2
        params[:order][order_index] = { :column => index, :dir => order }
      end

      response = Typhoeus.get(data_tables_api_url, http_options.deep_merge(admin_token).deep_merge({
        :params => params,
      }))
      assert_response_code(200, response)
      data = MultiJson.load(response.body)

      record_ids = records.map { |r| r.id }
      ordered_ids = []
      data.fetch("data").each do |result|
        if(record_ids.include?(result.fetch("id")))
          ordered_ids << result.fetch("id")
        end
      end

      ordered_ids
    end
  end
end
