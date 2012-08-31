require 'rake/clean'
require 'rake/testtask'
require 'rdoc/task'
require 'rubygems/package_task'

%w[png gif ps svg dot].each {|format| CLEAN.add "*.#{format}" }

# build gem ===================================================================
load("gemspec")
Gem::PackageTask.new(GEM_SPEC) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

# rdoc ========================================================================
RDoc::Task.new do |rdoc|
  rdoc.rdoc_files.include.include(*GEM_SPEC.files)
  rdoc.options << "--all"
end


# test ========================================================================
%w[test/parser.rb test/graph.rb].each {|testfile|
  Rake::TestTask.new("test_#{File.basename(testfile,".rb")}".to_sym) do |t|
    t.test_files = [testfile]
    t.verbose = true
    t.warning = true
  end
}
# vim:ft=ruby
