require 'pp'
require 'rgl/adjacency'
require 'rgl/dot'
require 'rgl/rdot'
require 'rgl/traversal'
require 'thread'
require 'digest'
require 'asciify'
require 'json'

module Codegraph
  VERSION = '0.7.17'
end

class FunctionGraph < RGL::DirectedAdjacencyGraph
   attr_accessor :funx, :adds, :excludes, :debug

   # Theses Parameters are used by interactive representation and for the file
   # generation function to_dot and to_type. They can only be given for the
   # whole graph, not for a singel node. This could be done by extending the
   # dot.rb file of the Ruby Graph Library
   Params = {'rankdir'     => 'LR',
             'ranksep'     => '4.0',
             'concentrate' => 'TRUE',
             'label'       => '',
             'fontsize'    => '12'}

   @@home        = ENV['HOME']
   @@codehomedir = "#{@@home}/.codegraph"
   @@filesDB     = @@codehomedir+'/filesDB.json'
   @@funxDB      = @@codehomedir+'/funxDB.json'

   @@matchBeforFuncName = $options[:matchBefor].nil? ? '[^A-z0-9_]( *)': $options[:matchBefor]
   @@matchAfterFuncName = $options[:matchAfter].nil? ? '( *\(| |$)'   : $options[:matchAfter]

   @@map = Asciify::Mapping.new(:default) 
   
   # Generate the codegraph storage directory
   if not FileTest.directory?(@@codehomedir) 
      system("mkdir #{@@codehomedir}")
   end

   def initialize
      super
      @debug   = false
      # the following attribute will hold the functionnames and their bodies
      @funx    = Hash.new
      @lock    = Mutex.new
      @filesDB = File.exist?(@@filesDB) ? JSON.parse(File.open(@@filesDB).read) : Hash.new
      @filesCk = @db.hash
      @funxDB  = File.exist?(@@funxDB) ? JSON.parse(File.open(@@funxDB).read) : Hash.new
      @funxCk  = @funxDB.hash

      @adds, @excludes = [],[]
   end
   
   # Generates the necessary files:
   # 1. One for the whole source code
   # 2. One for functions inside the file 1
   #  and fill the @funx hash
   def genFiles(graph, filelist, exclude=[])
      threads = []

      filelist.each {|file|
        threads << Thread.new(file, @@codehomedir) {|file,codehomedir|
          funxFile   = "funxnames"
          ctagsKinds = $options[:ctagsopts].nil? ? '--c-kinds=f --fortran-kinds=fsip --php-kinds=f --perl-kinds=f' : $options[:ctagsopts]

          puts "Processing #{file} ..." if @debug
          checksum = Digest::SHA256.file(file).hexdigest
          if @filesDB.has_key?(checksum)
            code,funxLocations = @filesDB[checksum]
          else
            basefile = File.basename(file)
            tempfile = "_" + basefile
            case File.extname(file)
            when '.c','.h' 
              cppCommand = "cpp -w -fpreprocessed -E  -fdirectives-only #{file}  -o #{codehomedir}/#{tempfile} 2>/dev/null"
              cppCommand = "cpp -fpreprocessed #{file}  -o #{codehomedir}/#{tempfile} 2>/dev/null"
              grep       = "grep -v -e '^$' #{codehomedir}/#{tempfile} | grep -v -e '^#' > #{codehomedir}/#{basefile}"
            when '.f','.f77','.f90','.f95'
              cppCommand = "cp #{file} #{codehomedir}/#{tempfile}"
              grep       = "grep -v -e '^$' #{codehomedir}/#{tempfile} | grep -v -e '^ *!' > #{codehomedir}/#{basefile}"
            else
              cppCommand = "cp #{file} #{codehomedir}/#{tempfile}"
              grep       = "grep -v -e '^$' #{codehomedir}/#{tempfile} | grep -v -e '^#' > #{codehomedir}/#{basefile}"
            end
            gen4ctags  = "ctags -x #{ctagsKinds}  #{codehomedir}/#{basefile} | sort -n -k 3"
            command    = [cppCommand,grep].join(";")

            puts gen4ctags if @debug
            puts command if @debug
            system(command)

            code          = open(codehomedir+'/'+ File.basename(file)).readlines
            funxLocations = IO.popen(gen4ctags).readlines.map {|l| l.split[0,4]}
            @lock.synchronize { @filesDB[checksum] = [code,funxLocations] }

            # cleanup
            FileUtils.rm("#{codehomedir}/#{tempfile}")
            FileUtils.rm("#{codehomedir}/#{basefile}")
          end

          funxLocations.each_with_index {|ary,i|
            name, kind, line, file = ary
            puts name if @debug
            line           = line.to_i
            startLineIndex = line - 1
            endLineIndex   = (i+1 < funxLocations.size) ? funxLocations[i+1][2].to_i - 2 : -1
            body = code[startLineIndex..endLineIndex].join
            @lock.synchronize {
              @funx.store(name,body)
            }
          }
        }
      }
      threads.each {|t| t.join}

      # update the code database in case of anything new
      updateFilesDB

      if @funx.empty?
         warn "no functions found"
         exit -1
      end
   end
   
   # fill the graph with all functions found in <filelist> 
   # while all functions from <exclude> aren't recognized
   def fill(filelist,exclude=[])
      # generate the necessary files and fill @funx
      genFiles(self,filelist,exclude)

      # scan functions for the function names
      names = @funx.keys
      @funx.each_pair {|name,body|
#        threads=[];threads << Thread.new(name,body,names) {|name,body,names|
          puts "Add func: #{name}" if @debug
          # Check if this body is in the funx DB
          bodyCk = Digest::SHA256.hexdigest(body)
          if @funxDB.has_key?(bodyCk) and @funxDB[name] == body
            edges = @funxDB[bodyCk]
            edges.each {|edge| add_edge(*edge)}
          else
            edges = []
            add_vertex(name)
            (names - [name] + @adds).each { |func|
              puts name if @debug
              if/#@@matchBeforFuncName#{func}#@@matchAfterFuncName/.match(body)
                edge = ["#{name}","#{func}"]
                add_edge(*edge)
                edges << edge
              end
            }
#            @lock.synchronize { 
              @funxDB[bodyCk] = edges
              @funxDB[name]   = body
#            }
          end
#        }
      }
      threads.each {|t| t.join}
     updateFunxDB
   end

   def limit(depth)
     dv = RGL::DFSVisitor.new(self)
     dv.attach_distance_map
     self.depth_first_search(dv) {|u|
       self.remove_vertex(u) if dv.distance_to_root(u) > depth
     }
   end

  def display_functionbody(name)
    @funx[name]
  end
   # Creates a simple dot file according to the above <Params>. 
   # Parameters for the nodes are not supported by rgl.
   def to_dot(filename)
      File.open(filename,"w") {|f|
         print_dotted_on(Params,f)
      }
   end

   # Generates pairs of "func_A -> func_B" to stdout
   def to_txt
      each_edge do |left,right|
         print left,' -> ',right,"\n"
      end
   end

   # This function generates a file of the given type using the dot utility.
   # Supported Types are PS, PNG, JPG, DOT and SVG.
   def to_type(filename,type)
      if File.exist?(filename) 
         system("rm #{filename}")
      end
      if File.exist?(filename+"."+type) 
         system("rm #{filename}."+type)
      end
      to_dot(filename+".dot")
      system("dot -T#{type} -o #{filename} -Nshape=box #{filename}.dot")
      system("rm #{filename}.dot")
   end

   # Display the graph with an interactive viewer
   def display
      dotty(Params)
      system("rm graph.dot") if File.exist?("graph.dot")
   end

   def updateFilesDB
      File.open(@@filesDB,"w") {|f| f << JSON.generate(@filesDB)} unless @filesCk == @filesDB.hash
   end
   def updateFunxDB
      File.open(@@funxDB,"w") {|f| f << JSON.generate(@funxDB)} unless @funxCk == @filesDB.hash
   end
   private :genFiles,:updateFilesDB,:updateFunxDB
end

class SingleFunctionGraph < FunctionGraph
   attr_accessor  :func

   # Constructor, which creates an empty graph for the rootfunction <func>
   def initialize(func)
      # Holds the func'n names, that are allready scanned
      @scannednames = []
      # Root func
      @func = func
      super()
   end

   # Works like the one from FunctionGraph except, that it calls 'scan' 
   # for the recursive descent throug all functions given in <filelist> - exclude
   def fill(filelist,exclude=[])
      genFiles(self,filelist,exclude)
      scan(self, func)
   end

   # For the given root function f, scan walks through the graph, and finds any
   # other function, that calls f
   def scan(graph,f)
      if (@scannednames.include?(f)) 
      else
         names = graph.funx.keys
         if not names.include?(func)
            warn "Function #{func} not found."
            exit -1
         end
         @scannednames << f
         body = graph.funx[f]
         # scan for any other function in the body of f
         (names - [f] + @adds).each {|g|
            if /#@@matchBeforFuncName#{g}#@@matchAfterFuncName/.match(body) 
               graph.add_edge(f,g)
               # go downstairs for all functions from the scanned files
               scan(graph,g) if names.include?(g)
            end
         }
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
            if/#@@matchBeforFuncName#{func}#@@matchAfterFuncName/.match(Asciify.new(@@map).convert(gbody))
               graph.add_edge(g,func)
               scan(graph,g)
            end
         }
      end
   end
   private :scan
end

class EightFunctionGraph < FunctionGraph
  def initialize(func)
    super()
    @func = func
  end
  def fill(*args)
    g_down = SingleFunctionGraph.new(@func)
    g_down.fill(*args)

    g_up   = UpperFunctionGraph.new(@func)
    g_up.fill(*args)

    g_down.each_edge do |u,v|
      self.add_edge(u,v)
    end
    g_up.each_edge do |u,v|
      self.add_edge(u,v)
    end
  end
end
