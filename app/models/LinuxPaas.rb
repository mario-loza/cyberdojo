
class LinuxPaas

  def initialize(disk, git, runner)
    @disk,@git,@runner = disk,git,runner
  end

  #- - - - - - - - - - - - - - - - - - - - - - - -

  def create_dojo(root, format)
    Dojo.new(self, root, format)
  end

  def make_kata(language, exercise, id, now)
    kata = Kata.new(language.dojo, id)
    manifest = {
      :created => now,
      :id => id,
      :language => language.name,
      :exercise => exercise.name,
      :unit_test_framework => language.unit_test_framework,
      :tab_size => language.tab_size
    }
    manifest[:visible_files] = language.visible_files
    manifest[:visible_files]['output'] = ''
    manifest[:visible_files]['instructions'] = exercise.instructions
    disk_make_dir(kata)
    disk_write(kata, kata.manifest_filename, manifest)
    kata
  end

  #- - - - - - - - - - - - - - - - - - - - - - - -
  # each() iteration

  def languages_each(languages)
    Dir.entries(path(languages)).select do |name|
      yield name if is_dir?(File.join(path(languages), name))
    end
  end

  def exercises_each(exercises)
    Dir.entries(path(exercises)).each do |name|
      yield name if is_dir?(File.join(path(exercises), name))
    end
  end

  def katas_each(katas)
    Dir.entries(path(katas)).each do |outer_dir|
      outer_path = File.join(path(katas), outer_dir)
      if is_dir?(outer_path)
        Dir.entries(outer_path).each do |inner_dir|
          inner_path = File.join(outer_path, inner_dir)
          if is_dir?(inner_path)
            yield outer_dir + inner_dir
          end
        end
      end
    end
  end

  def avatars_each(kata)
    Dir.entries(path(kata)).each do |name|
      yield name if is_dir?(File.join(path(kata), name))
    end
  end

  #- - - - - - - - - - - - - - - - - - - - - - - -

  def start_avatar(kata)
    avatar = nil
    started_avatar_names = kata.avatars.collect { |avatar| avatar.name }
    unstarted_avatar_names = Avatar.names - started_avatar_names
    if unstarted_avatar_names != [ ]
      avatar_name = unstarted_avatar_names.shuffle[0]
      avatar = Avatar.new(kata,avatar_name)

      disk_make_dir(avatar)
      git_init(avatar, '--quiet')

      disk_write(avatar, avatar.visible_files_filename, kata.visible_files)
      git_add(avatar, avatar.visible_files_filename)

      disk_write(avatar, avatar.traffic_lights_filename, [ ])
      git_add(avatar, avatar.traffic_lights_filename)

      kata.visible_files.each do |filename,content|
        disk_write(avatar.sandbox, filename,content)
        git_add(avatar.sandbox, filename)
      end

      kata.language.support_filenames.each do |filename|
        old_name = path(kata.language) + filename
        new_name = path(avatar.sandbox) + filename
        @disk.symlink(old_name, new_name)
      end

      avatar.commit(tag=0)
    end
    avatar
  end

  #- - - - - - - - - - - - - - - - - - - - - - - -
  # disk-helpers

  def disk_make_dir(object)
    dir(object).make
  end

  def disk_read(object, filename)
    dir(object).read(filename)
  end

  def disk_write(object, filename, content)
    dir(object).write(filename, content)
  end

  #- - - - - - - - - - - - - - - - - - - - - - - -
  # git-helpers

  def git_init(object, args)
    @git.init(path(object), args)
  end

  def git_add(object, filename)
    @git.add(path(object), filename)
  end

  def git_rm(object, filename)
    @git.rm(path(object), filename)
  end

  def git_commit(object, args)
    @git.commit(path(object), args)
  end

  def git_tag(object, args)
    @git.tag(path(object), args)
  end

  def git_diff(object, args)
    @git.diff(path(object), args)
  end

  def git_show(object, args)
    @git.show(path(object), args)
  end

  #- - - - - - - - - - - - - - - - - - - - - - - -
  # runner-helper

  def runner_run(object, command, max_duration)
    @runner.run(path(object), command, max_duration)
  end

  #- - - - - - - - - - - - - - - - - - - - - - - -

  def dir(obj)
    @disk[path(obj)]
  end

  def path(obj)
    case obj
      when Languages
        root(obj) + 'languages/'
      when Language
        path(obj.dojo.languages) + obj.name + '/'
      when Exercises
        root(obj) + 'exercises/'
      when Exercise
        path(obj.dojo.exercises) + obj.name + '/'
      when Katas
        root(obj) + 'katas/'
      when Kata
        path(obj.dojo.katas) + obj.id[0..1] + '/' + obj.id[2..-1] + '/'
      when Avatar
        path(obj.kata) + obj.name + '/'
      when Sandbox
        path(obj.avatar) + 'sandbox/'
    end
  end

  def root(obj)
    obj.dojo.path
  end

private

  def is_dir?(name)
    File.directory?(name) && !name.end_with?('.') && !name.end_with?('..')
  end

end

# idea is that this will hold methods that forward to external
# services namely: disk, git, shell.
# And I will create another implementation IsolatedDockerPaas
# Design notes
#
# o) locking is not right.
#    I need a 'Paas::Session' object which can scope the lock/unlock
#    over a sequence of actions. The paas object can hold this itself
#    since a new Paas object is created for each controller-action
#    CHECK THAT IS INDEED TRUE and that the same paas object is remembered
#    inside the controller
#         def paas
#           @paas ||= expression
#         end
#
# o) IsolatedDockerPaas.disk will have smarts to know if reads/writes
#    are local to disk (eg exercises) or need to go into container.
#    ExposedLinuxPaas.disk can have several dojos (different root-dirs eg testing)
#    so parent refs need to link back to dojo which
#    will be used by paas to determine paths.
#
# o) how will IsolatedDockerPaas know a languages'
#    initial visible_files? use same manifest format?
#    seems reasonable. Could even repeat the languages subfolder
#    pattern. No reason a Docker container could not support
#    several variations of language/unit-test.
#       - the docker container could have ruby code installed to
#         initialize an avatar from a language. All internally.
#         would save many docker run calls. Optimization.
#
# o) tests could be passed a paas object which they will use
#    idea is to repeat same test for several paas objects
#    eg one that spies completely
#    eg one that uses ExposedLinuxPaas
#    eg one that uses IsolatedDockerPaas
