require "rails_helper"

RSpec.describe DatatablesHelper do
  describe "#datatables_sort" do
    it "uses defaults to no order" do
      helper.stub(:params) { {} }
      expect(helper.datatables_sort).to eq([])
    end

    it "orders per request" do
      helper.stub(:params) do
        { :columns => { "0" => { :data => 'col0' }, "1" => { :data => 'col1' },
                        "2" => { :data => 'col2' }, "3" => { :data => 'col3' } },
          :order => [{ :column => '2', :dir => 'asc' }, { :column => '0', :dir => 'desc' }] }
      end
      expect(helper.datatables_sort).to eq([
        { 'col2' => 'asc' }, { 'col0' => 'desc' }
      ])
    end
  end

  describe "#param_index_array" do
    it "doesn't touch a parameter that's already an array" do
      helper.stub(:params) { { :key => ["a", "b", "c"] } }
      expect(helper.param_index_array(:key)).to eq(["a", "b", "c"])
    end

    it "converts parameters to arrays" do
      helper.stub(:params) { { :key => "value" } }
      expect(helper.param_index_array(:key)).to eq(["value"])
    end

    it "given an empty array when the parameter is not present" do
      helper.stub(:params) { {} }
      expect(helper.param_index_array(:key)).to eq([])
    end

    it "converts arrays with object indexes" do
      helper.stub(:params) { { :key => { "0" => "a", "1" => "b", "2" => "c" } } }
      expect(helper.param_index_array(:key)).to eq(["a", "b", "c"])
    end

    it "does not explode with missing indexes" do
      helper.stub(:params) { { :key => { "0" => "a", "2" => "c" } } }
      expect(helper.param_index_array(:key)).to eq(["a"])
    end

    it "does not explode with mixed indexes" do
      helper.stub(:params) { { :key => { "0" => "a", "str" => "b", "2" => "c" } } }
      expect(helper.param_index_array(:key)).to eq(["a", "c"])
    end
  end

  describe "#datatables_columns" do
    it "pulls out column data under realistic conditions" do
      helper.stub(:params) do
        { :columns => {
          "0" => { :data => "username", :name => "Username", :searchable => true,
                   :orderable => true, :search => { :value => '', :regex => false } },
          "1" => { :data => "email", :name => "E-mail", :searchable => true,
                   :orderable => true, :search => { :value => '', :regex => false } },
          "2" => { :data => "name", :name => "Name", :searchable => true,
                   :orderable => true, :search => { :value => '', :regex => false } },
        } }
      end
      expect(helper.datatables_columns).to eq([
        { :name => 'Username', :field => 'username' },
        { :name => 'E-mail', :field => 'email' },
        { :name => 'Name', :field => 'name' },
      ])
    end

    it "accounts for data errors" do
      helper.stub(:params) do
        { :columns => {
          "0" => { :name => "Username", :searchable => true, # missing data
                   :orderable => true, :search => { :value => '', :regex => false } },
          "1" => { :data => "email", :searchable => true, # missing name
                   :orderable => true, :search => { :value => '', :regex => false } },
          "2" => { :data => ["a", "b", "c"], :name => "Name", :searchable => true, # data is an array
                   :orderable => true, :search => { :value => '', :regex => false } },
        } }
      end
      expect(helper.datatables_columns).to eq([
        { :name => '-', :field => 'email' },
        { :name => 'Name', :field => '["a", "b", "c"]' },
      ])
    end
  end

  describe "#csv_output" do
    it "generates a csv" do
      results = [{ "a" => 1, "b" => 2, "c" => 3 }, { "a" => 4, "b" => 5, "c" => 6 }]
      columns = [{ :name => "A", :field => "a" }, { :name => "B", :field => "b" }, { :name => "C", :field => "c" }]
      output = helper.csv_output(results, columns)
      expect(output).to eq("A,B,C\n1,2,3\n4,5,6\n")
    end

    it "does not include fields not requested" do
      results = [{ "a" => 1, "b" => 2, "c" => 3 }, { "a" => 4, "b" => 5, "c" => 6 }]
      columns = [{ :name => "A", :field => "a" }, { :name => "C", :field => "c" }]
      output = helper.csv_output(results, columns)
      expect(output).to eq("A,C\n1,3\n4,6\n")
    end

    it "skips over missing fields" do
      results = [{ "a" => 1, "c" => 3 }, { "a" => 4, "b" => 5, "c" => 6 }]
      columns = [{ :name => "A", :field => "a" }, { :name => "B", :field => "b" }, { :name => "C", :field => "c" }]
      output = helper.csv_output(results, columns)
      expect(output).to eq("A,B,C\n1,,3\n4,5,6\n")
    end

    it "converts lists to a string" do
      results = [{ "a" => 1, "b" => [2, 3, 4] }]
      columns = [{ :name => "A", :field => "a" }, { :name => "B", :field => "b" }]
      output = helper.csv_output(results, columns)
      expect(output).to eq("A,B\n1," + '"2,3,4"' + "\n")
    end
  end

  describe "#respond_to_datatables" # @todo
end
