$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require "minitest/autorun"
require "codegraph"
require "thread"
require "pp"
require "jobqueue"
require "tempfile"

FORTRAN_SOURCE_0 = "test.f90"
FORTRAN_SOURCE_1 = "module_B.f90"
C_SOURCE         = "test00.c"

$LOCAL = 'nearly' == `hostname`.chomp

def tempPath
  t = Tempfile.new(rand.to_s)
  path = t.path
  t.close
  t.unlink
  path
end

class TestGraph < Minitest::Test

  DISPLAY = {'png' => 'sxiv','svg' => 'chromium'}

  thisdir     = FileUtils.pwd
  @@testdir   = File.basename(thisdir) == 'test' ? thisdir : [thisdir,'test'].join(File::SEPARATOR)
  @@test0_f90 = [@@testdir,FORTRAN_SOURCE_0].join(File::SEPARATOR)
  @@test1_f90 = [@@testdir,FORTRAN_SOURCE_1].join(File::SEPARATOR)
  @@test0_c   = [@@testdir,C_SOURCE].join(File::SEPARATOR)
  @@filelist  = [@@test0_f90,@@test1_f90]

  def display(graph,filename,type='png')
    graph.save(filename,type)
    system("#{DISPLAY[type]} #{filename}.#{type}") if $LOCAL
  end

  def testFG
    fg = FunctionGraph.new(:filelist => @@filelist)
    fg.scan
    ofile = 'testfncgraph'
    display(fg,ofile)
  end
  def testSFG
    filelist = [@@test0_f90,@@test1_f90]
    sg  = SingleFunctionGraph.new(:filelist => @@filelist,:function => 'transfer',:dir => tempPath)
    sg_ = SingleFunctionGraph.new(:filelist => @@filelist,:function => 'xfer_var',:dir => tempPath)
    display(sg,'testsg')
    display(sg_,'testsg_')
  end
  def testUFG
    sg = UpperFunctionGraph.new(:filelist => @@filelist,:function => 'xfer_idx_2',:debug => true,:dir => tempPath)
    ofile = 'testufg'
    display(sg,ofile)
  end
  def _test8FG
    efg = EightFunctionGraph.new(:filelist => @@filelist,:function => 'xfer_idx_3',:debug => false,:dir => tempPath)
    display(efg,'test8fg')
  end

  def testFileGraph
    fileG = FileGraph.new(:filelist => @@filelist,:debug => true,:dir => tempPath)
    sg  = SingleFunctionGraph.new(:filelist => @@filelist,:function => 'transfer',:dir => tempPath)
    fileG.subgraph(sg)
    display(fileG,'testFileG')
  end

  def test_f90_modules
    fg = FunctionGraph.new(:filelist => @@filelist)
  end

  if $LOCAL then
    def _setup
      puts "CleanUp ~/.codegraph...."
      Dir.glob("#{ENV['HOME']}/.codegraph/*.json").each {|f| 
        puts " ... remove #{f}"
        FileUtils.rm(f)
      }
    end
    def test_icon
      filelist = Dir.glob("#{ENV['HOME']}/src/git/icon/src/**/*f90")
      fg = SingleFunctionGraph.new(:filelist => filelist,:function => 'ice_slow',
                                   :debug => false,:dir => tempPath,
                                  :excludes => %w[< <= > >= - + * /= = ==])
      fg.scan if false
      fg.rotate
      fg.node_attribs << fg.box
      display(fg,'testicon','svg')
    end
    def test_icon_full
      filelist = Dir.glob("#{ENV['HOME']}/src/git/icon/src/shared/*f90")
      fg = SingleFunctionGraph.new(:function => 'add_var',:filelist => filelist,:debug => true,:excludes => ['+','-','*','==','finish'],:dir => tempPath)
      fg.rotate
      ofile = 'testiconfull'
      display(fg,ofile)
    end
    def test_icon_filegraph
      filelist = Dir.glob("#{ENV['HOME']}/src/git/icon/src/ocean/**/*f90")
      fileg =     FileGraph.new(:filelist => filelist,:dir => tempPath)
      funcg = FunctionGraph.new(:filelist => filelist,:dir => tempPath)
      funcg.scan

      ofile = 'testiconfiles'
      display(fileg,ofile,'svg') if true
      return
      display(funcg,ofile) if false

      fileg.subgraph(funcg)
      fileg.rotate
      fileg.node_attribs << fileg.box
      display(fileg,'funxPlusfiles','svg')
    end
    def test_cdo
      sg  = SingleFunctionGraph.new(:filelist =>[@@test0_c] ,:function => 'Copy',:debug => true,:dir => tempPath)
      display(sg,'cdo')
    end
    def test_icon_modules
      fg = SingleFunctionGraph.new(:debug => false,:ctagsOpts => '--fortran-kinds=m',:dir => tempPath,:filelist => Dir.glob("/home/ram/src/git/icon/src/**/*.f90"),
                             :matchBefor => 'USE\s+', :matchAfter => '(,| |$)',
                                 :function => 'mo_ocean_model')
      display(fg,'iconModules')
    end
    def test_mpas
      filelist = Dir.glob("#{ENV['HOME']}/src/MPAS-Release/src/core_ocean/*.F")
      funcg = FunctionGraph.new(:filelist => filelist,:dir => tempPath)
      funcg.scan
      funcg.rotate
      funcg.node_attribs << funcg.box
      ofile = 'testMPAS'
      display(funcg,ofile)
    end
    def test_mpiom
      filelist = Dir.glob("#{ENV['HOME']}/src/mpiom/src/*.f90")
      funcg = FunctionGraph.new(:filelist => filelist,:dir => tempPath,:excludes => ['+','-','*','==','/='])
      funcg.scan
      funcg.rotate
      funcg.node_attribs << funcg.box
      ofile = 'testMPIOM'
      display(funcg,ofile)
    end
  end# if false
end
