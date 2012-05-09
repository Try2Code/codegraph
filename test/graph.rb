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
