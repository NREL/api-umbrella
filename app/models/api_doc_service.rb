class ApiDocService
  include Mongoid::Document

  HTTP_METHODS = ["GET", "POST", "PUT", "DELETE", "HEAD"]

  field :http_method, :type => String
  field :path, :type => String
  field :url_path, :type => String
  field :summary, :type => String
  field :body, :type => String
  field :internal_only_access, :type => Boolean

  index [:http_method, :path], :unique => true
  index :url_path, :unique => true

  belongs_to :api_doc_collection

  validates_presence_of :http_method, :path, :summary, :body
  validates_inclusion_of :http_method, :in => HTTP_METHODS
  validates_uniqueness_of :path, :scope => :http_method

  after_initialize :assign_default_body
  before_save :generate_url_path

  def title
    @title ||= "#{http_method} #{path}"
  end

  private

  def generate_url_path
    self.url_path = File.join("/doc", self.path)
    if(self.http_method != "GET")
      self.url_path << self.http_method.downcase
    end
  end

  def assign_default_body
    self.body ||= <<EOS
<h2>Request URL</h2>
<div class="doc-service-url">GET http://developer.nrel.gov/api/example/service<em>.format?parameters</em></div>

<h2>Request Parameters</h2>
<table border="0" cellpadding="0" cellspacing="0" class="doc-parameters">
  <thead>
    <tr>
      <th scope="col" class="doc-parameters-name">Parameter</th>
      <th scope="col" class="doc-parameters-required">Required</th>
      <th scope="col" class="doc-parameters-value">Value</th>
      <th scope="col" class="doc-parameters-description">Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th scope="row" class="doc-parameter-name">format</th>
      <td class="doc-parameter-required">Yes</td>
      <td class="doc-parameter-value">
        <div class="doc-parameter-value-field"><strong>Type:</strong> string</div>
        <div class="doc-parameter-value-field"><strong>Default:</strong> None</div>
        <div class="doc-parameter-value-field"><strong>Options:</strong> <em>json</em>, <em>xml</em>, <em>csv</em></div>
      </td>
      <td class="doc-parameter-description">
        <p>The output response format.</p>
      </td>
    </tr>
    <tr>
      <th scope="row" class="doc-parameter-name">api_key</th>
      <td class="doc-parameter-required">Yes</td>
      <td class="doc-parameter-value">
        <div class="doc-parameter-value-field"><strong>Type:</strong> string</div>
        <div class="doc-parameter-value-field"><strong>Default:</strong> None</div>
      </td>
      <td class="doc-parameter-description">
        <p>Your developer API key. See <a href="/docs/faq#api_keys">API keys</a> for more information.</p>
      </td>
    </tr>
    <tr>
      <th scope="row" class="doc-parameter-name">example_param</th>
      <td class="doc-parameter-required">Yes/No/Depends</td>
      <td class="doc-parameter-value">
        <div class="doc-parameter-value-field"><strong>Type:</strong> string/integer/decimal/boolean/date/time</div>
        <div class="doc-parameter-value-field"><strong>Default:</strong> None/value</div>
        <div class="doc-parameter-value-field"><strong>Range:</strong> <em>1</em> to <em>100</em></div>
        <div class="doc-parameter-value-field"><strong>Options:</strong> <em>code1</em>, <em>code2</em>, <em>code3</em></div>
      </td>
      <td class="doc-parameter-description">
        <p>Parameter description...</p>

        <table border="0" cellpadding="0" cellspacing="0" class="doc-parameter-options">
          <thead>
            <tr>
              <th scope="col">Option</th>
              <th scope="col">Description</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <th scope="row">code1</th>
              <td>Description for code1</td>
            </tr>
          </tbody>
        </table>
      </td>
    </tr>

  </tbody>
</table>

<h2>Response Fields</h2>
<table border="0" cellpadding="0" cellspacing="0" class="doc-parameters">
  <thead>
    <tr>
      <th scope="col" class="doc-parameters-name">Field</th>
      <th scope="col" class="doc-parameters-value">Value</th>
      <th scope="col" class="doc-parameters-description">Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th scope="row" class="doc-parameter-name">field_name</th>
      <td class="doc-parameter-value">
        <div class="doc-parameter-value-field"><strong>Type:</strong> string/integer/decimal/boolean/date/time</div>
        <div class="doc-parameter-value-field"><strong>Range:</strong> 1 to 100</div>
      </td>
      <td class="doc-parameter-description">
        <p>Field description...</p>

        <table border="0" cellpadding="0" cellspacing="0" class="doc-parameter-options">
          <thead>
            <tr>
              <th scope="col">Option</th>
              <th scope="col">Description</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <th scope="row">code1</th>
              <td>Description for code1</td>
            </tr>
          </tbody>
        </table>
      </td>
    </tr>
  </tbody>
</table>

<h2>Examples</h2>
<h3>JSON Output Format</h3>
<div class="doc-example-url">GET <a href="http://developer.nrel.gov/api/example/service.json?api_key=DEMO_KEY">http://developer.nrel.gov/api/example/service.json?api_key=DEMO_KEY</a></div>
<pre class="brush:jscript;">
[
  {
    "id": 1,
    "value": "example",
  }
]
</pre>

<h3>XML Output Format</h3>
<div class="doc-example-url">GET <a href="http://developer.nrel.gov/api/example/service.xml?api_key=DEMO_KEY">http://developer.nrel.gov/api/example/service.xml?api_key=DEMO_KEY</a></div>
<pre class="brush:xml;">
&lt;?xml version="1.0" encoding="UTF-8"?&gt;
&lt;records type="array"&gt;
  &lt;record&gt;
    &lt;id&gt;1&lt;/id&gt;
    &lt;value&gt;example&lt;/value&gt;
  &lt;/record&gt;
&lt;/records&gt;
</pre>
EOS
  end
end
