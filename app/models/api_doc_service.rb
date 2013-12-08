class ApiDocService
  include Mongoid::Document

  HTTP_METHODS = %w(GET POST PUT DELETE HEAD)

  field :http_method, :type => String
  field :path, :type => String
  field :url_path, :type => String
  field :summary, :type => String
  field :body, :type => String
  field :internal_only_access, :type => Boolean

  index({ :http_method => 1, :path => 1 }, { :unique => true })
  index({ :url_path => 1 }, { :unique => true })

  belongs_to :api_doc_collection

  validates :http_method,
    :presence => true,
    :inclusion => { :in => HTTP_METHODS }
  validates :path,
    :presence => true,
    :uniqueness => true
  validates :summary,
    :presence => true
  validates :body,
    :presence => true

  after_initialize :assign_default_body
  before_save :generate_url_path

  def title
    @title ||= "#{http_method} #{path}"
  end

  # @return [String] The first paragraph of the summary.
  def summary_intro
    @summary_intro ||= self.summary.to_s.split(/[\r\n]/).first
  end

  def url_path
    @url_path ||= File.join(ActionController::Base.config.relative_url_root.to_s, self[:url_path])
  end

  private

  def generate_url_path
    self.url_path = File.join("/doc", self.path)
    if(self.http_method != "GET")
      self.url_path = File.join(self.url_path, self.http_method.downcase)
    end
  end

  def assign_default_body
    self.body ||= <<EOS
<h2>Request URL</h2>
<div class="doc-service-url">GET http://api.data.gov/api/example/service<em>.format?parameters</em></div>

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
        <p>Your developer API key. See <a href="/doc/api-key">API keys</a> for more information.</p>
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
        <div class="doc-parameter-value-field"><strong>Range:</strong> <em>1</em> to <em>100</em></div>
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
<div class="doc-example-url">GET <a href="http://api.data.gov/api/example/service.json?api_key=DEMO_KEY">http://api.data.gov/api/example/service.json?api_key=DEMO_KEY</a></div>
<pre class="brush:jscript;">
[
  {
    "id": 1,
    "value": "example",
  }
]
</pre>

<h3>XML Output Format</h3>
<div class="doc-example-url">GET <a href="http://api.data.gov/api/example/service.xml?api_key=DEMO_KEY">http://api.data.gov/api/example/service.xml?api_key=DEMO_KEY</a></div>
<pre class="brush:xml;">
&lt;?xml version="1.0" encoding="UTF-8"?&gt;
&lt;records type="array"&gt;
  &lt;record&gt;
    &lt;id&gt;1&lt;/id&gt;
    &lt;value&gt;example&lt;/value&gt;
  &lt;/record&gt;
&lt;/records&gt;
</pre>

<h2 id="rate-limits">Rate Limits</h2>
<p><a href="/doc/rate-limits">Standard rate limits</a> apply. No more than 1,000 requests may be made in any hour. No more than 10,000 requests may be made in any day.</p>

<h2 id="errors">Errors</h2>
<p><a href="/doc/errors">Standard errors</a> may be returned. In addition, the following service-specific errors may be returned:</p>
<table border="0" cellpadding="0" cellspacing="0" class="doc-parameters">
  <thead>
    <tr>
      <th class="doc-parameters-name" scope="col" style="width: 100px;">HTTP Status Code</th>
      <th class="doc-parameters-required" scope="col">Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th class="doc-parameter-name" scope="row">422</th>
      <td class="doc-parameter-description">Unprocessable Entity - Error description...</td>
    </tr>
  </tbody>
</table>
EOS
  end
end
