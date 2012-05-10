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

  def display(graph,filename)
    graph.save(filename,'png')
    system("qiv #{filename}.png") if 'thingol' == `hostname`.chomp
  end

  def testFG
    filelist = [@@test0_f90,@@test1_f90]
    fg = FunctionGraph.new({:filelist => filelist})
    fg.scan
    ofile = 'testfncgraph'
    display(fg,ofile)
  end
  def testSFG
    filelist = [@@test0_f90,@@test1_f90]
    sg = SingleFunctionGraph.new(:filelist => filelist,:func => 'transfer')
    ofile = 'testsg'
    display(sg,ofile)
  end
  def testUFG
    filelist = [@@test0_f90,@@test1_f90]
    sg = UpperFunctionGraph.new(:filelist => filelist,:func => 'xfer_idx_2',:debug => false)
    ofile = 'testufg'
    display(sg,ofile)
  end
  def test8FG
    filelist = [@@test0_f90,@@test1_f90]
    efg = EightFunctionGraph.new(:filelist => filelist,:func => 'xfer_idx_3',:debug => true)
    pp efg.funx
    display(efg,'test8fg')
  end

  if `hostname`.chomp == 'thingol' then
    def test_icon
      filelist = Dir.glob("#{ENV['HOME']}/src/git/icon/src/oce_dyn*/*f90")
      fg = FunctionGraph.new({:filelist => filelist})
      fg.scan
      fg.rotate
      ofile = 'testicon'
      display(fg,ofile)
    end
  end
end
