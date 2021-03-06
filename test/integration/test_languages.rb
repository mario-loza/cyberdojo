#!/usr/bin/env ruby

require_relative '../cyberdojo_test_base'

class LanguageTests < CyberDojoTestBase

  def setup
    super
    @root_path = root_path
  end

  test "all languages underneath root_path/languages" do
    assert File.directory?(root_path + '/languages/')
    languages_names = Dir.entries(root_path + '/languages').select { |name|
      manifest = root_path + "/languages/#{name}/manifest.json"
      name != '.' and name != '..' and File.file?(manifest)
    }
    languages_names.sort.each do |language_name|
      check(language_name)
    end
  end

  def check(language_name)
    @language = language_name

    assert manifest_file_exists?
    assert required_keys_exist?
    assert !unknown_keys_exist?
    assert !duplicate_visible_filenames?
    assert !duplicate_support_filenames?
    assert progress_regexs_valid?
    assert !filename_extension_starts_with_dot?
    assert cyberdojo_sh_exists?
    assert cyberdojo_sh_has_execute_permission?
    assert all_visible_files_exist?
    assert all_support_files_exist?
    assert highlight_filenames_are_subset_of_visible_filenames?
    assert colour_method_for_unit_test_framework_output_exists?
    assert !any_files_owner_is_root?
    assert !any_files_group_is_root?
    assert !any_file_is_unreadable?
    assert Dockerfile_exists?
    assert build_docker_container_exists?
    assert build_docker_container_starts_with_cyberdojo?
  end

  def manifest_file_exists?
    if !File.exists? manifest_filename
      message =
        alert +
        "#{manifest_filename} does not exist"
      puts message
      return false
    end
    print "."
    true
  end

  def required_keys_exist?
    required_keys = [ 'visible_filenames', 'unit_test_framework' ]
    required_keys.each do |key|
      if !manifest.keys.include? key
        message =
          alert +
          "#{manifest_filename} must contain key '#{key}'"
        puts message
        return false
      end
    end
    print "."
    true
  end

  def unknown_keys_exist?
    known = [ 'visible_filenames',
              'support_filenames',
              'progress_regexs',
              'filename_extension',
              'highlight_filenames',
              'unit_test_framework',
              'tab_size',
              'display_name',
              'display_test_name',
              'image_name'
            ]
    manifest.keys.each do |key|
      if !known.include? key
        message =
          alert +
          "#{manifest_filename} contains unknown key '#{key}'"
        puts message
        return true
      end
    end
    print "."
    false
  end

  def duplicate_visible_filenames?
    visible_filenames.each do |filename|
      if visible_filenames.count(filename) > 1
        message =
          alert +
          "  #{manifest_filename}'s 'visible_filenames' contains #{filename} more than once"
        puts message
        return true
      end
    end
    print "."
    false
  end

  def duplicate_support_filenames?
    support_filenames.each do |filename|
      if support_filenames.count(filename) > 1
        message =
          alert +
          "  #{manifest_filename}'s 'support_filenames' contains #{filename} more than once"
        puts message
        return true
      end
    end
    print '.'
    false
  end

  def progress_regexs_valid?
    if progress_regexs.class.name != "Array"
        message =
          alert + " #{manifest_filename}'s progress_regexs entry is not an array"
        puts message
        return false
    end

    if progress_regexs.length != 0 && progress_regexs.length != 2
        message =
          alert + " #{manifest_filename}'s progress_regexs entry does not contain 2 entries"
        puts message
        return false
    end

    progress_regexs.each do |s|
      begin
        Regexp.new(s)
      rescue
        message =
          alert + " #{manifest_filename} cannot create a Regexp from #{s}"
        puts message
        return false
      end
    end
    print '.'
    true
  end

  def filename_extension_starts_with_dot?
    if manifest['filename_extension'][0] != '.'
      message =
        alert +
        " #{manifest_filename}'s 'filename_extension' does not start with a ."
        puts message
        return true
    end
    print '.'
    false
  end

  def all_visible_files_exist?
    all_files_exist?(:visible_filenames)
  end

  def all_support_files_exist?
    all_files_exist?(:support_filenames)
  end

  def all_files_exist?(symbol)
    (manifest[symbol] || [ ]).each do |filename|
      if !File.exists?(language_dir + '/' + filename)
        message =
          alert +
          "  #{manifest_filename} contains a '#{symbol}' entry [#{filename}]\n" +
          "  but the #{language_dir}/ dir does not contain a file called #{filename}"
        puts message
        return false
      end
    end
    print "."
    true
  end

  def highlight_filenames_are_subset_of_visible_filenames?
    highlight_filenames.each do |filename|
      if filename != 'instructions' &&
           filename != 'output' &&
           !visible_filenames.include?(filename)
        message =
          alert +
          "  #{manifest_filename} contains a 'highlight_filenames' entry ['#{filename}']\n" +
          "  but visible_filenames does not include '#{filename}'"
        puts message
        return false
      end
    end
    print "."
    true
  end

  def cyberdojo_sh_exists?
    filenames = visible_filenames + support_filenames
    if filenames.select{ |filename| filename == "cyber-dojo.sh" } == [ ]
      message =
        alert +
        "  #{manifest_filename} must contain ['cyber-dojo.sh'] in \n" +
        "  'visible_filenames' or 'support_filenames'"
      puts message
      return false
    end
    print "."
    true
  end

  def cyberdojo_sh_has_execute_permission?
    if !File.stat(language_dir + '/' + 'cyber-dojo.sh').executable?
      message =
        alert +
          " 'cyber-dojo.sh does not have execute permission"
        puts message
        return false
    end
    print "."
    true
  end

  def colour_method_for_unit_test_framework_output_exists?
    has_parse_method = true
    begin
      OutputParser::colour(unit_test_framework, "xx")
    rescue
      has_parse_method = false
    end
    if !has_parse_method
      message =
        alert +
          "app/lib/OutputParser.rb does not contain a " +
          "parse_#{unit_test_framework}(output) method"
      puts message
      return false
    end
    print "."
    true
  end

  def any_files_owner_is_root?
    # for HostTestRunner
    (visible_filenames + support_filenames + ['manifest.json']).each do |filename|
      uid = File.stat(language_dir + '/' + filename).uid
      owner = Etc.getpwuid(uid).name
      if owner == 'root'
        message =
          alert +
            "owner of #{language_dir}/#{filename} is root"
        puts message
        return true
      end
    end
    print "."
    false
  end

  def any_files_group_is_root?
    # for HostTestRunner
    (visible_filenames + support_filenames + ['manifest.json']).each do |filename|
      gid = File.stat(language_dir + '/' + filename).gid
      owner = Etc.getgrgid(gid).name
      if owner == 'root'
        message =
          alert +
            "owner of #{language_dir}/#{filename} is root"
        puts message
        return true
      end
    end
    print "."
    false
  end

  def any_file_is_unreadable?
    (visible_filenames + support_filenames + ['manifest.json']).each do |filename|
      if !File.stat(language_dir + '/' + filename).world_readable?
        message =
          alert +
            "#{language_dir}/#{filename} is not world-readable"
        puts message
        return true
      end
    end
    print "."
    false
  end

  def Dockerfile_exists?
    if !File.exists?(language_dir + '/' + 'Dockerfile')
      message =
        alert +
        "  #{language_dir}/ dir does not contain a file called Dockerfile"
      puts message
      return false
    end
    print "."
    true
  end

  def build_docker_container_exists?
    if !File.exists?(language_dir + '/' + 'build-docker-container.sh')
      message =
        alert +
        "  #{language_dir}/ dir does not contain a file called build-docker-container.sh"
      puts message
      return false
    end
    print "."
    true
  end

  def build_docker_container_starts_with_cyberdojo?
    filename = language_dir + '/' + 'build-docker-container.sh'
    content = IO.read(filename)
    if !/docker build -t cyberdojo/.match(content)
      message =
        alert +
        " #{filename} does not contain 'docker build -t cyberdojo/"
      puts message
      return false
    end
    print "."
    true
  end

private

  def language
    @language
  end

  def language_dir
    @root_path + '/languages/' + language
  end

  def manifest_filename
    language_dir + '/' + 'manifest.json'
  end

  def manifest
    JSON.parse(IO.read(manifest_filename))
  end

  def visible_filenames
    manifest['visible_filenames'] || [ ]
  end

  def support_filenames
    manifest['support_filenames'] || [ ]
  end

  def progress_regexs
    manifest['progress_regexs'] || [ ]
  end

  def highlight_filenames
    manifest['highlight_filenames'] || [ ]
  end

  def unit_test_framework
    manifest['unit_test_framework'] || [ ]
  end

  def alert
    "\n>>>>>>>#{language}<<<<<<<\n"
  end

end
