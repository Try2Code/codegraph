require 'thread'
require 'graph'
require 'digest'
require 'json'
require 'fileutils'
require 'pp'


module Codegraph
  VERSION = '0.7.19'
end

class CodeParser
  attr_reader   :funxLocations, :funx
  attr_accessor :exclude

  @@ctagsOpts   = '--c-kinds=f --fortran-kinds=fsip --php-kinds=f --perl-kinds=f'
  @@workDir     = ENV['HOME'] + '/.codegraph'
  @@filesDBfile = @@workDir+'/filesDB.json'
  @@filesDB     = File.exist?(@@filesDBfile) ? JSON.parse(File.open(@@filesDBfile).read) : Hash.new
  @@filesCk     = @@filesDB.hash
  @@lock        = Mutex.new

  def CodeParser.filesDB
    @@filesDB
  end
  def CodeParser.filesCk
    @@filesCk
  end

  def initialize(debug=false,dir="#{ENV['HOME']}/.codegraph")
    @dir   = dir
    @debug = debug
    @funx  = {}
    @exclude = []
  end
  def read(*filelist)
    threads = []

    filelist.each {|file|
      threads << Thread.new(file, @dir) {|file,dir|
        puts "Cannot find file #{file}" unless File.exist?(file)
        puts "Processing #{file} ..." if @debug
        checksum = Digest::SHA256.file(file).hexdigest
        if @@filesDB.has_key?(checksum)
          code,@funxLocations = @@filesDB[checksum]
        else
          basefile = File.basename(file)
          tempfile = "_" + basefile
          case File.extname(file)
          when '.c','.h'
            cppCommand = "cpp -w -fpreprocessed -E  -fdirectives-only #{file}  -o #{dir}/#{tempfile} 2>/dev/null"
            cppCommand = "cpp -fpreprocessed #{file}  -o #{dir}/#{tempfile} 2>/dev/null"
            grep       = "grep -v -e '^$' #{dir}/#{tempfile} | grep -v -e '^#' > #{dir}/#{basefile}"
          when '.f','.f77','.f90','.f95'
            cppCommand = "cp #{file} #{dir}/#{tempfile}"
            grep       = "grep -v -e '^$' #{dir}/#{tempfile} | grep -v -e '^ *!' > #{dir}/#{basefile}"
          else
            cppCommand = "cp #{file} #{dir}/#{tempfile}"
            grep       = "grep -v -e '^$' #{dir}/#{tempfile} | grep -v -e '^#' > #{dir}/#{basefile}"
          end
          gen4ctags  = "ctags -x #{@@ctagsOpts}  #{dir}/#{basefile} | sort -n -k 3"
          command    = [cppCommand,grep].join(";")

          puts gen4ctags if @debug
          puts command if @debug
          system(command)

          code          = open(dir+'/'+ File.basename(file)).readlines
          @funxLocations = IO.popen(gen4ctags).readlines.map {|l| l.split[0,4]}
          @@lock.synchronize { @@filesDB[checksum] = [code,@funxLocations] }

          # cleanup
          FileUtils.rm("#{dir}/#{tempfile}") unless @debug
          FileUtils.rm("#{dir}/#{basefile}") unless @debug
        end
        @funxLocations.each_with_index {|ary,i|
          name, kind, line, file = ary
          next if @exclude.include?(name)
          puts name if @debug
          line           = line.to_i
          startLineIndex = line - 1
          endLineIndex   = (i+1 < funxLocations.size) ? funxLocations[i+1][2].to_i - 2 : -1
          body = code[startLineIndex..endLineIndex].join
          @@lock.synchronize {
            @funx.store(name,body)
          }
        }
      }
    }
    threads.each {|t| t.join}

    updateFilesDB
  end
  def updateFilesDB
     File.open(@@filesDBfile,"w") {|f| f << JSON.generate(@@filesDB)} unless @@filesCk == @@filesDB.hash
  end
  private :updateFilesDB
end

class FunctionGraph < Graph
  attr_accessor :funx, :adds, :excludes, :debug

  @@workDir     = ENV['HOME'] + '/.codegraph'
  @@funxDBfile = @@workDir+'/funxDB.json'
  @@funxDB     = File.exist?(@@funxDBfile) ? JSON.parse(File.open(@@funxDBfile).read) : Hash.new

  def initialize(config)
    super(self.class.to_s)
    @config  = config 

    @debug   = @config[:debug]
    # the following attribute will hold the functionnames and their bodies
    @parser  = CodeParser.new

    @@matchBeforFuncName = @config[:matchBefor].nil? ? '[^A-z0-9_]\s*': @config[:matchBefor]
    @@matchAfterFuncName = @config[:matchAfter].nil? ? '( *\(| |$)'   : @config[:matchAfter]

    @adds, @excludes = [],[]

    @parser.read(*@config[:filelist])
    @funx = @parser.funx
  end
   
  def scan
    # scan functions for the function names
    names = @parser.funx.keys
    @parser.funx.each_pair {|name,body|
      puts "Add func: #{name}" if @debug
      # Check if this body is in the funx DB
      bodyCk = Digest::SHA256.hexdigest(body)
      if @@funxDB.has_key?(bodyCk) and @@funxDB[name] == body
        edges = @@funxDB[bodyCk]
        edges.each {|edge| self.edge(*edge)}
      else
        edges = []
        self.node(name)
        (names - [name] + @adds).each { |func|
          #puts name if @debug
          if/#@@matchBeforFuncName#{Regexp.escape(func)}#@@matchAfterFuncName/.match(body)
            edge = ["#{name}","#{func}"]
            self.edge(*edge)
            edges << edge
          end
        }
        @@funxDB[bodyCk] = edges
        @@funxDB[name]   = body
      end
    }
    updateFunxDB
  end

  def display_functionbody(name)
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
    @func = @config[:func]
    scan(self,@func)
  end

  # For the given root function f, scan walks through the graph, and finds any
  # other function, that calls f
  def scan(graph,f)
    if (@scannednames.include?(f)) 
    else
      names = graph.funx.keys
      if names.include?('*') then
        puts 'body of *:'
        puts graph.funx['*']
      end
      if not names.include?(func)
        warn "Function #{func} not found."
        exit -1
      end
      @scannednames << f
      body   = graph.funx[f]
      bodyCk = Digest::SHA256.hexdigest(body)
      #       if @funxDB.has_key?(bodyCk) and @funxDB[f] == body
      #         edges = @funxDB[bodyCk]
      #         edges.each {|edge| add_edge(*edge)}
      #         (edges.flatten.uniq-[f]).each {|g| scan(graph,g)}
      #       else
      edges = []
      # scan for any other function in the body of f
      (names - [f] + @adds).each {|g|
        if /#@@matchBeforFuncName#{g}#@@matchAfterFuncName/.match(body) 
          graph.edge(f,g)
          edges << [f,g]
          # go downstairs for all functions from the scanned files
          scan(graph,g) if names.include?(g)
        end
      }
      #         @funxDB[bodyCk] = edges
      #         @funxDB[f]      = body
      #       end
    end
  end
  private :scan
end

class UpperFunctionGraph < SingleFunctionGraph

  # scanning upwards unlike SingleFunctionGraph.scan
  def scan(graph,func)
    if @scannednames.include?(func) 
    else
      if not (graph.funx.keys + @adds).include?(func)
        warn "Function '#{func}' not found. If this is an internal function, " +
          "please try again with the '-w' option to include the internal " +
          "funx before scanning."
        exit -1
      end
      @scannednames << func
      graph.funx.each_pair {|g,gbody|
        # dont scan a function for itself
        next if g == func
        puts g if @debug
        puts gbody if @debug
        if/#@@matchBeforFuncName#{func}#@@matchAfterFuncName/.match(gbody)
          graph.edge(g,func)
          scan(graph,g)
        end
      }
    end
  end
  private :scan
end

class EightFunctionGraph < Graph
  def initialize(config)
    super(config)
  end
  def scan
    g_down = SingleFunctionGraph.new(@config)
    g_up   = UpperFunctionGraph.new(@config)
    self.edges = g_down.edges#.merge(g_up.edges)
  end
end
