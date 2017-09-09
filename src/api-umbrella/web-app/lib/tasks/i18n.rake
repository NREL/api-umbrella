namespace :i18n do
  task :to_gettext => :environment do
    def escape(string)
      string.gsub(/([\\"\t\n])/) do
        special_character = $1
        case special_character
        when "\t"
          "\\t"
        when "\n"
          "\\n"
        else
          "\\#{special_character}"
        end
      end
    end

    def i18n_to_gettext(en_data, locale_data, path = [], gettext_data = {})
      if(en_data.kind_of?(Hash))
        locale_data ||= {}
        unless locale_data.kind_of?(Hash)
          puts "Mismatched type: #{path.join(".")}: #{locale_data}"
          locale_data = {}
        end

        en_data.each do |key, value|
          i18n_to_gettext(value, locale_data[key], path + [key], gettext_data)
        end
      elsif(en_data.kind_of?(Array))
        locale_data ||= []
        unless locale_data.kind_of?(Array)
          puts "Mismatched type: #{path.join(".")}: #{locale_data}"
          locale_data = []
        end

        en_data.each_with_index do |value, index|
          i18n_to_gettext(value, locale_data[index], path + [index], gettext_data)
        end
      elsif(en_data.nil? || en_data.to_s.empty?)
        puts "Empty key: #{path.join(".")}"
      else
        gettext_data[en_data.to_s] = {
          :value => locale_data.to_s,
          :path => path,
        }
      end

      gettext_data
    end

    def write_po(gettext_data, file, skip_empty = false)
      gettext_data.keys.sort.each do |key|
        value = gettext_data[key][:value]
        if(!skip_empty || (skip_empty && !value.to_s.empty?))
          file.puts("")
          file.puts("# #{gettext_data[key][:path].join(".")}")
          file.puts("msgid \"#{escape(key.strip)}\"")
          file.puts("msgstr \"#{escape(value.strip)}\"")
        end
      end
    end

    root_dir = ENV.fetch("ROOT_DIR")

    en_data = I18n.with_locale(:en) { I18n.t(".") }
    gettext_data = i18n_to_gettext(en_data, {})
    Dir.chdir(File.join(root_dir, "src/api-umbrella/admin-ui")) do
      js_paths = `git grep --fixed-strings -l ".t("`.strip.split("\n")
      js_paths.each do |path|
        puts path.inspect
        content = File.read(path)

        gettext_data.each do |en_key, data|
          content.gsub!("I18n.t('#{data[:path].join(".")}'", "i18n.t('#{en_key.gsub("'", "\\\\'").gsub("\n", "\\n")}'")
        end

        File.open(path, "w") { |f| f.write(content) }
      end

      hbs_paths = `git grep --fixed-strings -l "{{t "`.strip.split("\n")
      hbs_paths += `git grep --fixed-strings -l "(t "`.strip.split("\n")
      hbs_paths.uniq!
      hbs_paths.each do |path|
        puts path.inspect
        content = File.read(path)

        gettext_data.each do |en_key, data|
          content.gsub!("{{t \"#{data[:path].join(".")}\"", "{{t #{en_key.inspect}")
          content.gsub!("(t \"#{data[:path].join(".")}\"", "(t #{en_key.inspect}")
        end

        File.open(path, "w") { |f| f.write(content) }
      end
    end

    FileUtils.mkdir_p(File.join(root_dir, "locale"))
    File.open(File.join(root_dir, "locale/api-umbrella.pot"), "w") do |file|
      file.puts('msgid ""')
      file.puts('msgstr ""')
      file.puts('"Language: \n"')
      file.puts('"MIME-Version: 1.0\n"')
      file.puts('"Content-Type: text/plain; charset=UTF-8\n"')
      file.puts('"Content-Transfer-Encoding: 8bit\n"')
      write_po(gettext_data, file)
    end

    I18n.available_locales.each do |locale|
      next if(locale == :en)
      locale_data = I18n.with_locale(locale) { I18n.t(".") }
      gettext_data = i18n_to_gettext(en_data, locale_data)

      lang = locale.to_s.gsub("-", "_")
      File.open(File.join(root_dir, "locale/#{lang}.po"), "w") do |file|
        file.puts('msgid ""')
        file.puts('msgstr ""')
        file.puts(%("Language: #{lang}\\n"))
        file.puts('"MIME-Version: 1.0\n"')
        file.puts('"Content-Type: text/plain; charset=UTF-8\n"')
        file.puts('"Content-Transfer-Encoding: 8bit\n"')
        write_po(gettext_data, file, true)
      end
    end
  end
end
