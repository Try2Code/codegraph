$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require "test/unit"
require "codegraph"
require "thread"
require "pp"
require "jobqueue"

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

class TestCodeParser < Test::Unit::TestCase

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

  def test_CodeParser
    cp = CodeParser.new
    cp.read(@@test0_f90)
    pp cp
#    assert_equal(elementsOf(@@test0_f90), CodeParser.filesDB.map {|v| v[1]}.flatten.transpose[0])
#   assert_equal(typesOf(@@test0_f90),cp.funxLocations.transpose[1])
#   assert_equal(linesOf(@@test0_f90),cp.funxLocations.transpose[2])
#   assert_equal(elementsOf(@@test0_f90),cp.funx.keys)
#   cp.read(@@test1_f90)
#   assert_equal(elementsOf(@@test1_f90), cp.funxLocations.transpose[0])
#   assert_equal(typesOf(@@test1_f90),cp.funxLocations.transpose[1])
#   assert_equal(linesOf(@@test1_f90),cp.funxLocations.transpose[2])
#   assert_equal(elementsOf(@@test0_f90)+elementsOf(@@test1_f90),cp.funx.keys)

    assert_equal("SUBROUTINE construct()\nDO jg = 1,n\n  CALL allocate_int_state( )\n  CALL scalar_int_coeff()\nENDDO\nEND SUBROUTINE construct\n",
                 cp.funx["construct"])

    myfunx = cp.funx
    cp.read(@@test0_f90,@@test1_f90)
    assert_equal(myfunx,cp.funx)
    cp.read(@@test0_f90,@@test1_f90)
    cp.read(@@test0_f90,@@test1_f90)
    cp.read(@@test0_f90,@@test1_f90)
    assert_equal(myfunx,cp.funx)
  end

  def test_CodeParser_threaded_init
    threads = []
    [ @@test0_f90,@@test1_f90,
      @@test0_f90,@@test1_f90,
      @@test0_f90,@@test1_f90 ].each {|file|
      threads << Thread.new(file) {|file|
       cp = CodeParser.new
       cp.read(file)
#      assert_equal(elementsOf(file),cp.funxLocations.transpose[0])
#      assert_equal(typesOf(file),cp.funxLocations.transpose[1])
#      assert_equal(linesOf(file),cp.funxLocations.transpose[2])
      }
    }
    threads.each {|t| t.join}
  end
  def test_CodeParser_threaded_read
    cp = CodeParser.new
    threads = []
    [ @@test0_f90,@@test1_f90].each {|file|
      threads << Thread.new(cp,file) {|cp,file| cp.read(file) }
    }
    threads.each {|t| t.join}
    cp4comparison = CodeParser.new
    cp4comparison.read(@@test0_f90,@@test1_f90)
    assert_equal(cp4comparison.funx.sort,cp.funx.sort)
  end

  def test_files_relation
    cp = CodeParser.new
    [ @@test0_f90,@@test1_f90].each {|file| cp.read(file) }
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
  end

  def _testAll
    tObj, threads   = TestCdoGSL.new(:test_gsl), []
    self.class.public_instance_methods.sort.grep(/^test_\w.*/).delete_if {|m| tObj.method(m.to_sym).arity != 0}.each {|test|
      threads << Thread.new(test) {|_test| system("ruby test_eca.rb -n #{_test}")}
    }
    threads.each {|t| t.join}
  end
end
