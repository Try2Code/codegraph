require 'jobqueue'
require 'graph'
require 'digest'
require 'json'
require 'fileutils'
require 'pp'
require 'ascii'


module Codegraph
  VERSION = '0.7.22'
end

class CodeParser
  include Digest

  attr_reader   :funx,:files
  attr_accessor :exclude,:ctagsOpts

  @@ctagsOpts   = '--c-kinds=f --fortran-kinds=fsip --php-kinds=f --perl-kinds=f'
  @@workDir     = ENV['HOME'] + '/.codegraph'
  @@filesDBfile = @@workDir+'/filesDB.json'
  @@filesDB     = File.exist?(@@filesDBfile) ? JSON.parse(File.open(@@filesDBfile).read) : Hash.new
  @@filesCk     = @@filesDB.hash
  @@lock        = Mutex.new

  # come class methods
  def CodeParser.filesDB
    @@filesDB
  end
  def CodeParser.filesCk
    @@filesCk
  end
  def updateCacheLocation
    @@filesDBfile = @dir+'/filesDB.json'
    pp @@filesDBfile if @debug
    @@filesDB     = File.exist?(@@filesDBfile) ? JSON.parse(File.open(@@filesDBfile).read) : Hash.new
    @@filesCk     = @@filesDB.hash
  end
  #=============================================================================

  def initialize(config={})
    @debug        = config[:debug].nil?        ? false       : config[:debug]
    @dir          = config[:dir].nil?          ? @@workDir   : config[:dir]
    @ctagsOpts    = config[:ctagsOpts].nil?    ? @@ctagsOpts : config[:ctagsOpts]
    @disableCache = config[:disableCache].nil? ? false       : config[:disableCache]
    @funx, @files = {},{}
    @exclude      = []

    FileUtils.mkdir_p(@dir) unless File.directory?(@dir)
    updateCacheLocation if @dir != @@workDir
  end

  def read(*filelist)
    jobqueue = JobQueue.new

    filelist.each {|file|
      jobqueue.push {
        unless File.exist?(file)
          warn "Cannot find file #{file}"
          return
        else
          puts "Processing #{file} ..." if @debug
        end

        checksum = hexencode(file)
        #if @disableCache or (@@filesDB.has_key?(checksum) and @@filesDB.has_key?(file))
        if @@filesDB.has_key?(checksum) and @@filesDB.has_key?(file)
          code,funxLocations = @@filesDB[checksum]
          @files[file]       = @@filesDB[file]
        else
          basefile = File.basename(file)
          tempfile = "_" + basefile
          case File.extname(file)
          when '.c','.h'
            cppCommand = "cpp -w -fpreprocessed -E  -fdirectives-only #{file}  -o #{@dir}/#{tempfile} 2>/dev/null"
            cppCommand = "cpp -fpreprocessed #{file}  -o #{@dir}/#{tempfile} 2>/dev/null"
            grep       = "grep -v -e '^$' #{@dir}/#{tempfile} | grep -v -e '^#' | perl -pi -e " << '\'s/".[^"]*"//g\'' << " > #{@dir}/#{basefile}"
          when '.f','.f77','.f90','.f95'
            cppCommand = "cp #{file} #{@dir}/#{tempfile}"
            grep       = "grep -v -e '^$' #{@dir}/#{tempfile} | grep -v -e '^ *!' > #{@dir}/#{basefile}"
          else
            cppCommand = "cp #{file} #{@dir}/#{tempfile}"
            grep       = "grep -v -e '^$' #{@dir}/#{tempfile} | grep -v -e '^#' > #{@dir}/#{basefile}"
          end
          gen4ctags  = "ctags -x #{@ctagsOpts}  #{@dir}/#{basefile} | sort -n -k 3"
          command    = [cppCommand,grep].join(";")

          puts gen4ctags if @debug
          puts command if @debug
          system(command)

          puts File.basename(file) if @debug
          code          = open(@dir+'/'+ File.basename(file)).readlines.map {|l| Ascii.process(l) }
          funxLocations = IO.popen(gen4ctags).readlines.map {|l| l.split[0,4]}
          @@lock.synchronize { 
            @@filesDB[checksum] = [code,funxLocations]
            @@filesDB[file]     = funxLocations.map {|v| v[0]}
            @files[file]        = @@filesDB[file]
          }

          # cleanup
          FileUtils.rm("#{@dir}/#{tempfile}") unless @debug
          FileUtils.rm("#{@dir}/#{basefile}") unless @debug
        end
        funxLocations.each_with_index {|ary,i|
          name, kind, line, file = ary
          next if @exclude.include?(name)
          puts name if @debug
          line           = line.to_i
          startLineIndex = line - 1
          endLineIndex   = (i+1 < funxLocations.size) ? funxLocations[i+1][2].to_i - 2 : -1
          body = Ascii.process(code[startLineIndex..endLineIndex].join)
          @@lock.synchronize {
            @funx.store(name,body)
          }
        }
      }
    }
    jobqueue.run

    updateFilesDB
  end
  def updateFilesDB
     File.open(@@filesDBfile+"test","w") {|f| f << @@filesDB.to_s} unless @@filesCk == @@filesDB.hash
     File.open(@@filesDBfile,"w") {|f| f << JSON.generate(@@filesDB)} unless @@filesCk == @@filesDB.hash
  end
  private :updateFilesDB
end

# needed for svg output
class Graph
  def empty?
    edges.empty?
  end
end

class FunctionGraph < Graph
  include Digest

  attr_accessor :funx, :adds, :excludes, :debug, :parser

  # internal database for former scans
  @@workDir    = ENV['HOME'] + '/.codegraph'
  @@funxDBfile = @@workDir+'/funxDB.json'
  @@funxDB     = File.exist?(@@funxDBfile) ? JSON.parse(File.open(@@funxDBfile).read) : Hash.new
  @@lock       = Mutex.new

  @@match = {
    :c => {},
    :f => {}
  }

  def initialize(config)
    super(self.class.to_s)
    @config  = config

    @debug        = @config[:debug].nil?        ? false       : @config[:debug]
    @dir          = @config[:dir].nil?          ? [ENV['HOME'],'.codegraph'].join("/")   : @config[:dir]
    @ctagsOpts    = @config[:ctagsOpts] unless @config[:ctagsOpts].nil?
    @disableCache = @config[:disableCache].nil? ? false       : @config[:disableCache]

    @@matchBeforFuncName = @config[:matchBefor].nil? ? '[^A-z0-9_]\s*': @config[:matchBefor]
    @@matchAfterFuncName = @config[:matchAfter].nil? ? '( *\(| |$)'   : @config[:matchAfter]
#    @@matchBeforFuncName = @config[:matchBefor].nil? ? 'USE\s+': @config[:matchBefor]
#    @@matchAfterFuncName = @config[:matchAfter].nil? ? '(,| |$)'   : @config[:matchAfter]

    @adds     = @config[:adds] || []
    @excludes = @config[:excludes] || []

    @parser   = CodeParser.new(@config)
    @parser.read(*@config[:filelist])
    @funx     = @parser.funx
  end
   
  def scan
    jobqueue = JobQueue.new
    # scan functions fo all other function names
    names = @parser.funx.keys + @adds - @excludes
    @parser.funx.each_pair {|name,body|
      next unless names.include?(name)
      jobqueue.push {
        puts "Add func: #{name}" if @debug
        # Check if this body is in the funx DB
        bodyCk = hexencode(body)
        #if @disableCache or (@@funxDB.has_key?(bodyCk) and @@funxDB[name] == body)
        if @@funxDB.has_key?(bodyCk) and @@funxDB[name] == body
          edges = @@funxDB[bodyCk]
          edges.each {|edge| self.edge(*edge)}
        else
          edges = []
          self.node(name)
          (names - [name]).each { |func|
            if/#@@matchBeforFuncName#{Regexp.escape(func)}#@@matchAfterFuncName/.match(body)
              edge = ["#{name}","#{func}"]
              self.edge(*edge)
              edges << edge
            end
          }
          @@lock.synchronize {
            @@funxDB[bodyCk] = edges
            @@funxDB[name]   = body
          }
        end
      }
    }
    jobqueue.run

    updateFunxDB
  end

  def showBody(name)
    @funx[name]
  end

  def updateFunxDB
    File.open(@@funxDBfile,"w") {|f| f << JSON.generate(@@funxDB)}# unless @funxCk == @parser.filesCk
  end
  private :updateFunxDB
end

class SingleFunctionGraph < FunctionGraph
  attr_accessor  :func

  # Constructor, which creates an empty graph for the rootfunction <func>
  def initialize(config)
    super(config)
    # Holds the func'n names, that are allready scanned
    @scannednames = []
    # Root func
    @func = @config[:function]
    scan(self,@func)
  end

  # For the given root function f, scan walks through the graph, and finds any
  # other function, that calls f
  def scan(graph,f)
    puts "Scanning #{f} ..." if @config[:debug]
    if (@scannednames.include?(f)) 
      return
    else
      names = graph.funx.keys + @adds - @excludes
      unless names.include?(f)
        warn "Function #{func} not found."
        return
      end
      @scannednames << f
      body   = graph.funx[f]
      bodyCk = hexencode(body)
      #if @disableCache or (@@funxDB.has_key?(bodyCk) and @@funxDB[f] == body)
      if @@funxDB.has_key?(bodyCk) and @@funxDB[f] == body
        edges = @@funxDB[bodyCk]
        edges.each {|edge| graph.edge(*edge)}
        (edges.flatten.uniq-[f]).each {|g| scan(graph,g)}
      else
        edges = []
        # scan for any other function in the body of f
        (names - [f]).each {|g|
          if /#@@matchBeforFuncName#{Regexp.escape(g)}#@@matchAfterFuncName/.match(body)
            graph.edge(f,g)
            edges << [f,g]
            # go downstairs for all functions from the scanned files
            scan(graph,g) if names.include?(g)
          end
        }
        #@@lock.synchronize {
          @@funxDB[bodyCk] = edges
          @@funxDB[f]      = body
        #}
      end
    end
  end
  private :scan
end

class UpperFunctionGraph < SingleFunctionGraph

  # scanning upwards unlike SingleFunctionGraph.scan
  def scan(graph,func)
    if @scannednames.include?(func) 
    else
      names = graph.funx.keys + @adds - @excludes
      unless names.include?(func)
        warn "Function '#{func}' not found"
        exit false
      end
      @scannednames << func
      graph.funx.each_pair {|g,gbody|
        # dont scan a function for itself
        next if g == func
        puts g if @debug
        if/#@@matchBeforFuncName#{Regexp.escape(func)}#@@matchAfterFuncName/.match(gbody)
          graph.edge(g,func)
          scan(graph,g)
        end
      }
    end
  end
  private :scan
end

class EightFunctionGraph < FunctionGraph
  def initialize(config)
    super(config)
    @config = config
    gDown = SingleFunctionGraph.new(@config)
    gUp   = UpperFunctionGraph.new(@config)
  end
end

class FileGraph < Graph
  attr_reader :funx,:files
  def initialize(config)
    super(self.class.to_s)
    @config      = config
    @debug       = @config[:debug]
    @parser      = CodeParser.new
    @parser.read(*@config[:filelist])
    @funx,@files = @parser.funx, @parser.files

    scan
  end

  def scan
    leaf_node = white + filled
    @files.each {|file,myfunx|
      subgraph "cluster_#{rand(1000)}_#{file}" do
        label file
        graph_attribs << blue << filled << lightgray
        myfunx.each {|func| node(func)}
      end
    }
  end
end
