module ApplicationHelper
  def html_title
    title = "Data.gov Developer Network"

    if crumbs.any?
      title = "#{crumbs.last.first} | #{title}"
    end

    title
  end

  def highlight_code(language, code)
    process = ChildProcess.build("pygmentize", "-l", language.to_s, "-f", "html", "-O", "encoding=utf-8", "-O", "linenos=True")

    # Store the pygmentize output on a Tempfile.
    output = Tempfile.new("api-umbrella-pygmentize")
    process.io.stdout = output

    # Setup pipe so we can pass to stdin. 
    process.duplex = true

    process.start

    # Pass the code block to pygmentize via stdin pip.
    process.io.stdin.puts code
    process.io.stdin.close

    # Wait for pygmentize to complete with a 10 second timeout. 
    process.poll_for_exit(10)

    # Reade pygmentize's output.
    output.rewind
    highlighted = output.read

    %(<div class="highlight-code">#{highlighted}</div>).html_safe
  end

  def cached_highlight_code(language, code)
    cache("highlight_code_#{Digest::SHA1.hexdigest(code)}") do
      safe_concat(highlight_code(language, code))
    end
  end
end
