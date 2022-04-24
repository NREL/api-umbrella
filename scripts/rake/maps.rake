namespace :maps do
  # rubocop:disable Style/GlobalVars

  task :download do
    [
      "http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/50m/cultural/ne_50m_admin_1_states_provinces_lakes.zip",
      "http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/cultural/ne_110m_admin_0_countries_lakes.zip",
      "http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/cultural/ne_110m_admin_0_map_units.zip",
      "http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/50m/cultural/ne_50m_admin_0_countries_lakes.zip",
      "http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/50m/cultural/ne_50m_admin_0_map_units.zip",
      "http://dev.maxmind.com/static/csv/codes/iso3166.csv",
    ].each do |url|
      path = File.join($input_dir, File.basename(url))
      unless(File.exist?(path))
        sh("curl", "-L", "-o", path, url)
      end

      if(url.end_with?(".zip"))
        dir = path.chomp(".zip")
        unless(Dir.exist?(dir))
          sh("unzip", path, "-d", dir)
        end
      end
    end
  end

  task :world do
    require "csv"
    require "oj"

    maxmind_countries = {}
    CSV.foreach(File.join($input_dir, "iso3166.csv")) do |row|
      maxmind_countries[row[0]] = row[1]
    end

    [
      "110m",
      "50m",
    ].each do |scale|
      sovereignties_path = File.join($input_dir, "tmp/world-#{scale}-sovereignties.json")
      sh("ogr2ogr", "-f", "GeoJSON", "-where", "iso_a2 NOT IN('AQ')", "-t_srs", "EPSG:4326", sovereignties_path, File.join($input_dir, "ne_#{scale}_admin_0_map_units/ne_#{scale}_admin_0_map_units.shp"))

      countries_path = File.join($input_dir, "tmp/world-#{scale}-countries.json")
      sh("ogr2ogr", "-f", "GeoJSON", "-where", "iso_a2 NOT IN('AQ')", "-t_srs", "EPSG:4326", countries_path, File.join($input_dir, "ne_#{scale}_admin_0_countries_lakes/ne_#{scale}_admin_0_countries_lakes.shp"))

      sovereignties = Oj.load(File.read(sovereignties_path))
      countries = Oj.load(File.read(countries_path))

      # Add countries, like United Kingdom, as a single country that are
      # represented as separate sovereignties (so we align with MaxMind's
      # country mappings).
      sovereignties["features"] += countries["features"].find_all { |f| ["GB", "PG", "RS", "BA", "BE", "GE", "PT"].include?(f["properties"]["iso_a2"]) }

      sovereignties["features"].each do |feature|
        # Consider Metropolitan France the "FR" country.
        if(feature["properties"]["iso_a2"] == "-99" && feature["properties"]["adm0_a3"] == "FRA")
          feature["properties"]["iso_a2"] = "FR"
        end
      end

      # Remove non-country sovereignties.
      sovereignties["features"].reject! do |feature|
        if(feature["properties"]["iso_a2"] == "-99")
          puts "#{scale} Ignoring #{feature["properties"]["adm0_a3"]}: #{feature["properties"]["formal_en"] || feature["properties"]["name_long"]}"
          true
        else
          false
        end
      end

      countries_in_map = []
      sovereignties["features"].each do |feature|
        countries_in_map << feature["properties"]["iso_a2"]
      end

      # Compare the countries in the map to MaxMind's ISO3166 data to make sure
      # we have all the expected countries.
      missing_countries = (maxmind_countries.keys - countries_in_map).map { |k| maxmind_countries[k] }
      extra_countries = (countries_in_map - maxmind_countries.keys).map { |k| maxmind_countries[k] }
      puts "#{scale} Missing Countries: #{missing_countries.inspect}"
      puts "#{scale} Extra Countries: #{extra_countries.inspect}"

      combined_path = File.join($input_dir, "tmp/world-#{scale}-combined.json")
      File.write(combined_path, Oj.dump(sovereignties))
    end

    # Use the low resolution version for the globe.
    FileUtils.cp(File.join($input_dir, "tmp/world-110m-combined.json"), File.join($output_dir, "world.json"))

    # Use the medium resolution version to generate specific files for each
    # individual country.
    countries = Oj.load(File.read(File.join($input_dir, "tmp/world-50m-combined.json")))
    countries["features"].each do |feature|
      File.open(File.join($output_dir, "#{feature["properties"]["iso_a2"]}.json"), "w") do |file|
        country = countries.dup
        country["features"] = [country["features"].detect { |f| f["properties"]["iso_a2"] == feature["properties"]["iso_a2"] }]
        file.write(Oj.dump(country))
      end
    end
  end

  task :us do
    require "oj"

    output_path = File.join($output_dir, "US.json")
    FileUtils.rm_f(output_path)
    sh("ogr2ogr", "-f", "GeoJSON", "-where", "iso_a2 = 'US'", "-t_srs", "EPSG:4326", output_path, File.join($input_dir, "ne_50m_admin_1_states_provinces_lakes/ne_50m_admin_1_states_provinces_lakes.shp"))

    data = Oj.load(File.read(output_path))
    data["features"].each do |feature|
      case(feature["properties"]["iso_3166_2"])
      when "US-HI"
        # Remove Midway from Hawaii, since it's not one of the main islands and
        # makes Hawaii's display much wider than normal.
        feature["geometry"]["coordinates"].reject! { |c| c[0][0][0] < -177 }
      end

      File.open(File.join($output_dir, "#{feature["properties"]["iso_3166_2"]}.json"), "w") do |file|
        state_data = data.dup
        state_data["features"] = [state_data["features"].detect { |f| f["properties"]["iso_3166_2"] == feature["properties"]["iso_3166_2"] }]
        file.write(Oj.dump(state_data))
      end
    end
    File.write(output_path, Oj.dump(data))
  end

  task :simplify do
    require "oj"
    require "open3"

    Dir.glob(File.join($output_dir, "*.json")).each do |path|
      simplify = "0.5"
      if(path.end_with?("US.json"))
        simplify = "0.2"
      end

      puts "Simplifying #{path}"
      statuses = Open3.pipeline(
        ["geo2topo", "boundaries=#{path}"],
        ["toposimplify", "-P", simplify],
        ["topo2geo", "boundaries=#{path}"],
      )
      statuses.each do |status|
        unless(status.success?)
          puts "Simplifying failed: #{statuses.inspect}"
          exit 1
        end
      end

      data = Oj.load(File.read(path))
      data["_labels"] = {}
      data["features"].each do |feature|
        if(File.basename(path).start_with?("US"))
          code = feature["properties"]["iso_3166_2"]
        else
          code = feature["properties"]["iso_a2"]
        end

        data["_labels"][code] ||= feature["properties"]["name"]

        feature["properties"] = {
          "name" => code,
        }
      end
      File.write(path, Oj.dump(data, :float_precision => 9))
    end
  end

  task :generate do
    require "fileutils"

    $input_dir = ENV.fetch("INPUT_DIR", File.join(API_UMBRELLA_SRC_ROOT, "build/work/maps"))
    FileUtils.rm_rf(File.join($input_dir, "tmp"))
    FileUtils.mkdir_p(File.join($input_dir, "tmp"))

    $output_dir = File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella/admin-ui/public/maps")
    FileUtils.rm_rf($output_dir)
    FileUtils.mkdir_p($output_dir)

    Rake::Task["maps:download"].invoke
    Rake::Task["maps:world"].invoke
    Rake::Task["maps:us"].invoke
    Rake::Task["maps:simplify"].invoke
  end

  # rubocop:enable Style/GlobalVars
end
