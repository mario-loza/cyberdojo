#!/usr/bin/env ruby

require_relative '../cyberdojo_test_base'
require_relative 'externals'

class HostTestRunnerTests < CyberDojoTestBase

  include Externals

  def setup
    super
    @dojo = Dojo.new(root_path,externals)
  end

  test "HostTestRunner says it can run any language" do
    languages = @dojo.languages.entries
    actual = languages.map{|language| language.name}.sort
    expected =
    [
      "C#-NUnit",
      "C++-Catch",
      "C++-CppUTest",
      "C++-GoogleTest",
      "C++-assert",
      "C-Unity",
      "C-assert",
      "Clojure-.test",
      "CoffeeScript-jasmine",
      "D-unittest",
      "Erlang-eunit",
      "F#-NUnit",
      "Fortran-FUnit",
      "Go-testing",
      "Groovy-JUnit",
      "Groovy-Spock",
      "Haskell-hunit",
      "Java-1.8_Approval",
      "Java-1.8_Cucumber",
      "Java-1.8_JUnit",
      "Java-1.8_Mockito",
      "Java-1.8_Powermockito",
      "Javascript-assert",
      "Javascript-jasmine",
      "PHP-PHPUnit",
      "Perl-TestSimple",
      "Python-pytest",
      "Python-unittest",
      "Ruby-Approval",
      "Ruby-Cucumber",
      "Ruby-Rspec",
      "Ruby-TestUnit",
      "Scala-scalatest"
    ]

    assert_equal expected, actual
  end

end
