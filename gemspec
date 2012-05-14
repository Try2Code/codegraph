require 'rubygems'



spec = Gem::Specification.new do |s|
  s.name              = "codegraph"
  s.version           = File.open("lib/codegraph.rb").readlines.grep(/VERSION/)[0].split('=').last.chomp.strip.tr("'",'')
  s.date              = Time.new.strftime("%Y-%m-%d")
  s.platform          = Gem::Platform::RUBY
  s.bindir            = 'bin'
  s.files             = ["lib/codegraph.rb","bin/codegraph"] + ["gemspec","LICENSE"]
  s.executables       << 'codegraph'
  s.add_dependency('graph')
  s.rubyforge_project = "codegraph"
  s.description       = "Display functional dependencies in source code (C, Fortran, PHP, Perl).\n"
  s.summary           = "Display functional dependencies in source code (C, Fortran, PHP, Perl)"
  s.author            = "Ralf Mueller"
  s.email             = "stark.dreamdetective@gmail.com"
  s.homepage          = "http://codegraph.rubyforge.org"
  s.has_rdoc          = true
end

# vim:ft=ruby
