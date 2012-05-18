$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require "test/unit"
require "codegraph"
require "thread"
require "pp"
require "jobqueue"

FORTRAN_SOURCE_0 = "test.f90"
FORTRAN_SOURCE_1 = "module_B.f90"
C_SOURCE         = "test00.c"

class TestGraph < Test::Unit::TestCase

  DISPLAY = {'png' => 'sxiv','svg' => 'chromium'}

  thisdir     = FileUtils.pwd
  @@testdir   = File.basename(thisdir) == 'test' ? thisdir : [thisdir,'test'].join(File::SEPARATOR)
  @@test0_f90 = [@@testdir,FORTRAN_SOURCE_0].join(File::SEPARATOR)
  @@test1_f90 = [@@testdir,FORTRAN_SOURCE_1].join(File::SEPARATOR)
  @@test0_c   = [@@testdir,C_SOURCE].join(File::SEPARATOR)
  @@filelist  = [@@test0_f90,@@test1_f90]

  def display(graph,filename,type='png')
    graph.save(filename,type)
    system("#{DISPLAY[type]} #{filename}.#{type}") if 'thingol' == `hostname`.chomp
  end

  def testFG
    filelist = [@@test0_f90,@@test1_f90]
    fg = FunctionGraph.new(:filelist => filelist)
    fg.scan
    ofile = 'testfncgraph'
    display(fg,ofile)
  end
  def testSFG
    filelist = [@@test0_f90,@@test1_f90]
    sg  = SingleFunctionGraph.new(:filelist => filelist,:function => 'transfer')
    sg_ = SingleFunctionGraph.new(:filelist => filelist,:function => 'xfer_var')
    display(sg,'testsg')
    display(sg_,'testsg_')
  end
  def testUFG
    filelist = [@@test0_f90,@@test1_f90]
    sg = UpperFunctionGraph.new(:filelist => filelist,:function => 'xfer_idx_2',:debug => false)
    ofile = 'testufg'
    display(sg,ofile)
  end
  def _test8FG
    filelist = [@@test0_f90,@@test1_f90]
    efg = EightFunctionGraph.new(:filelist => filelist,:function => 'xfer_idx_3',:debug => false)
    display(efg,'test8fg')
  end

  def testFileGraph
    fileG = FileGraph.new(:filelist => @@filelist,:debug => true)
    sg  = SingleFunctionGraph.new(:filelist => @@filelist,:function => 'transfer')
    fileG.subgraph(sg)
    display(fileG,'testFileG')
  end

  if `hostname`.chomp == 'thingol' then
    def _setup
      puts "CleanUp ~/.codegraph...."
      Dir.glob("#{ENV['HOME']}/.codegraph/*.json").each {|f| 
        puts " ... remove #{f}"
        FileUtils.rm(f)
      }
    end
    def test_icon
      filelist = Dir.glob("#{ENV['HOME']}/src/git/icon/src/*/*f90")
      fg = SingleFunctionGraph.new(:filelist => filelist,:function => 'mo_hydro_ocean_run',:debug => true)
      fg.scan if false
      fg.rotate
      fg.node_attribs << fg.box
      display(fg,'testicon','svg')
    end
    def test_icon_full
      filelist = Dir.glob("#{ENV['HOME']}/src/git/icon/src/shared/*f90")
      fg = SingleFunctionGraph.new(:function => 'add_var',:filelist => filelist,:debug => true,:excludes => ['+','-','*','==','finish'])
      fg.rotate
      ofile = 'testiconfull'
      display(fg,ofile)
    end
    def test_icon_filegraph
      #filelist = Dir.glob("#{ENV['HOME']}/src/git/icon/src/*/*f90")
      filelist = Dir.glob("#{ENV['HOME']}/src/git/icon/src/oce_dyn*/*f90")
      fileg =     FileGraph.new(:filelist => filelist)
      funcg = FunctionGraph.new(:filelist => filelist)
      funcg.scan

      ofile = 'testiconfiles'
      display(fileg,ofile) if false
      display(funcg,ofile) if false

      fileg.subgraph(funcg)
      fileg.rotate
      fileg.node_attribs << fileg.box
      display(fileg,'funxPlusfiles','svg')
    end
    def test_cdo
      sg  = SingleFunctionGraph.new(:filelist =>[@@test0_c] ,:function => 'Copy',:debug => true)
      display(sg,'cdo')
    end
  end
end
