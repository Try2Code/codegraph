$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require "test/unit"
require "codegraph"


FORTRAN_SOURCE = "test.f90"

class TestCodeParser < Test::Unit::TestCase
thisdir = FileUtils.pwd
@@testdir = File.basename(thisdir) == 'test' ? thisdir : [thisdir,'test'].join(File::SEPARATOR)
@@testf90 = [@@testdir,FORTRAN_SOURCE].join(File::SEPARATOR)

  def test_me
    cp = CodeParser.new(@@testf90)
    pp cp
  end
  def _testAll
    tObj, threads   = TestCdoGSL.new(:test_gsl), []
    self.class.public_instance_methods.sort.grep(/^test_\w.*/).delete_if {|m| tObj.method(m.to_sym).arity != 0}.each {|test|
      threads << Thread.new(test) {|_test| system("ruby test_eca.rb -n #{_test}")}
    }
    threads.each {|t| t.join}
  end
end
