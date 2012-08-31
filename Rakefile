require 'rake/clean'
require 'rake/testtask'
require 'rdoc/task'
require 'rubygems/package_task'

CLEAN.add '*.dot'

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
Rake::TestTask.new(:test) do |t|
  t.test_files = Dir.glob("test/*.rb")
  t.verbose = true
  t.warning = true
end
# vim:ft=ruby
