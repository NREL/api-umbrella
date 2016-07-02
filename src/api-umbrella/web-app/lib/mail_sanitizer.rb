class MailSanitizer
  class InvalidAddress < StandardError
  end

  # A workaround to address OSVDB-131677 that is patched in the mail 2.6 gem,
  # but since we're still on Rails 3.2, we can't upgrade yet.
  #
  # If the fixes get backported (https://github.com/mikel/mail/issues/944),
  # then we could get rid of this, but in the meantime, this is a quick fix to
  # address the underlying issues related to newlines and lengths.
  #
  # See:
  # http://rubysec.com/advisories/OSVDB-131677/
  # http://www.mbsd.jp/Whitepaper/smtpi.pdf
  def self.sanitize_address(address)
    if(address)
      # Ensure no linebreaks are in the address.
      if(address =~ /[\r\n]/)
        raise InvalidAddress, "E-mail address cannot contain newlines"
      end

      # Ensure the address doesn't exceed 500 chars to prevent some servers
      # from wrapping the content, introducing line breaks (technically, longer
      # should work, but 500 seems like enough for our simple purposes).
      if(address.length > 500)
        raise InvalidAddress, "E-mail address cannot exceed 500 characters"
      end
    end

    address
  end
end
