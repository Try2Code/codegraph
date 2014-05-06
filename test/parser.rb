$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'minitest/autorun'
require "codegraph"
require "thread"
require "pp"
require 'json'
require "jobqueue"
require "tempfile"

FORTRAN_SOURCE_0 = "test.f90"
FORTRAN_SOURCE_1 = "module_B.f90"

FORTRAN_elements = [
    "xfer_var",
    "xfer_idx",
    "allocate_int_state",
    "construct",
    "xfer_var_r2",
    "xfer_var_r3",
    "xfer_var_r4",
    "xfer_var_i2",
    "xfer_idx_2",
    "xfer_idx_3",
    "transfer"
]
FORTRAN_types = [["interface"]*2,["subroutine"]*9].flatten
FORTRAN_lines = ["7", "13", "18", "20", "26", "28", "30", "32", "35", "38", "45"]

FORTRAN_structs  = {
  FORTRAN_SOURCE_0 => {
  :elements        => FORTRAN_elements,
  :types           => FORTRAN_types,
  :lines           => FORTRAN_lines
  },
  FORTRAN_SOURCE_1 => {
  :elements        => FORTRAN_elements.map {|item| item += '_B'},
  :types           => FORTRAN_types,
  :lines           => FORTRAN_lines
  }
}

def tempPath
  t = Tempfile.new(rand.to_s)
  path = t.path
  t.close
  t.unlink
  path
end

class TestCodeParser < Minitest::Test

  thisdir     = FileUtils.pwd
  @@testdir   = File.basename(thisdir) == 'test' ? thisdir : [thisdir,'test'].join(File::SEPARATOR)
  @@test0_f90 = [@@testdir,FORTRAN_SOURCE_0].join(File::SEPARATOR)
  @@test1_f90 = [@@testdir,FORTRAN_SOURCE_1].join(File::SEPARATOR)

  [:elements,:types,:lines].each {|pattern|
    define_method(pattern) {|type,file|
      case type
      when 'f90'
        FORTRAN_structs[File.basename(file)][pattern]
      else
        puts 'Unsupportet input type'
        return
      end
    }

    # create methods: elementsOf, typesOf and linesOf
    define_method((pattern.to_s + 'Of').to_sym) {|file|
      method(pattern).call(File.extname(file)[1..-1],file)
    }
  }

  if `hostname`.chomp == 'thingol' then

    def test_tempPath
      assert(! tempPath.nil?,"tempPath result is nil")
      assert_equal('/tmp',tempPath[0,4])
    end
    def _setup
      puts "CleanUp ~/.codegraph...."
      Dir.glob("#{ENV['HOME']}/.codegraph/*.json").each {|f| 
        puts " ... remove #{f}"
        FileUtils.rm(f)
      }
    end
    def test_icon
      cp = CodeParser.new
      cp.read(*Dir.glob("#{ENV['HOME']}/src/git/icon/src/oce_dyn*/*f90"))
      funx = cp.funx.keys
      ["map_cell2edges", "map_edges2cell", "calculate_oce_diagnostics"].each {|s| assert_include(funx,s)}
    end
  end


  def test_f90
    cpA = CodeParser.new(:debug => true,:dir => tempPath)
    cpA.read(@@test0_f90)

    assert_equal(["xfer_var",
                 "xfer_idx",
                 "allocate_int_state",
                 "construct",
                 "xfer_var_r2",
                 "xfer_var_r3",
                 "xfer_var_r4",
                 "xfer_var_i2",
                 "xfer_idx_2",
                 "xfer_idx_3",
                 "transfer"],cpA.funx.keys)

    assert_equal("SUBROUTINE construct()\nDO jg = 1,n\n  CALL allocate_int_state( )\n  CALL scalar_int_coeff()\nENDDO\nEND SUBROUTINE construct\n",
                 cpA.funx["construct"])

    cpB = CodeParser.new(:debug => true,:dir => tempPath)
    cpB.read(@@test1_f90)
    cpAll = CodeParser.new
    cpAll.read(@@test0_f90,@@test1_f90)
    assert_equal(cpAll.funx.sort,(cpA.funx.sort + cpB.funx.sort).sort)
  end

  def test_threaded_read
    cp = CodeParser.new
    threads = []
    [ @@test0_f90,@@test1_f90].each {|file|
      threads << Thread.new(cp,file) {|_cp,_file| _cp.read(_file) }
    }
    threads.each {|t| t.join}
    cp4comparison = CodeParser.new
    cp4comparison.read(@@test0_f90,@@test1_f90)
    assert_equal(cp4comparison.funx.sort,cp.funx.sort)
  end

  def test_files_relation
    cp = CodeParser.new(:debug => true,:dir => tempPath)
    cp.read(*[ @@test0_f90,@@test1_f90])
    assert_equal({"/home/ram/src/git/codegraph/test/test.f90"=>
		 ["xfer_var",
		   "xfer_idx",
		   "allocate_int_state",
		   "construct",
		   "xfer_var_r2",
		   "xfer_var_r3",
		   "xfer_var_r4",
		   "xfer_var_i2",
		   "xfer_idx_2",
		   "xfer_idx_3",
		   "transfer"],
		   "/home/ram/src/git/codegraph/test/module_B.f90"=>
		 ["xfer_var_B",
		   "xfer_idx_B",
		   "allocate_int_state_B",
		   "construct_B",
		   "xfer_var_r2_B",
		   "xfer_var_r3_B",
		   "xfer_var_r4_B",
		   "xfer_var_i2_B",
		   "xfer_idx_2_B",
		   "xfer_idx_3_B",
		   "transfer_B"]},cp.files)
  end

  def test_f90_modules
    cp = CodeParser.new(:debug => true,:ctagsOpts => '--fortran-kinds=m',:dir => tempPath)
    cp.read(@@test0_f90)
    assert_equal('A',cp.funx.keys.first)
    cp.read(@@test1_f90)
    assert_equal(['A','B','C'],cp.funx.keys)
  end
  def test_icon_modules
    cp = CodeParser.new(:debug => false,:ctagsOpts => '--fortran-kinds=m',:dir => tempPath,
                       :matchBefor => 'USE\s+', :matchAfter => '(,| |$)')
    cp.read(*Dir.glob("/home/ram/src/git/icon/src/**/*.f90"))
  end
end
