$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require "test/unit"
require "codegraph"
require "thread"
require "pp"
require "jobqueue"

FORTRAN_SOURCE_0 = "test.f90"
FORTRAN_SOURCE_1 = "module_B.f90"

class TestGraph < Test::Unit::TestCase

  thisdir     = FileUtils.pwd
  @@testdir   = File.basename(thisdir) == 'test' ? thisdir : [thisdir,'test'].join(File::SEPARATOR)
  @@test0_f90 = [@@testdir,FORTRAN_SOURCE_0].join(File::SEPARATOR)
  @@test1_f90 = [@@testdir,FORTRAN_SOURCE_1].join(File::SEPARATOR)

  def test_first
    filelist = [@@test0_f90,@@test1_f90]
    cp = FunctionGraph.new({:filelist => filelist})
    cp.scan
    cp.save('testfirst','png')
    system("qiv testfirst.png") if 'thingol' == `hostname`.chomp
  end
  if `hostname`.chomp == 'thingol' then
    def test_icon
      cp = CodeParser.new
      jq = JobQueue.new
      Dir.glob("#{ENV['HOME']}/src/git/icon/src/oce_dyn*/*f90").each {|file|
        puts file
        jq.push(cp,:read,file)
      }
      jq.run
      pp cp.funx.keys
    end
  end if false
end
