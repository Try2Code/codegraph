require 'rubygems'

GEM_SPEC = Gem::Specification.new do |s|
  s.name              = "codegraph"
  s.version           = '0.7.22'
  s.date              = Time.new.strftime("%Y-%m-%d")

  s.description       = "Display functional dependencies in source code (C, Fortran, PHP, Perl)"
  s.summary           = "Display functional dependencies in source code (C, Fortran, PHP, Perl)"

  s.platform          = Gem::Platform::RUBY
  s.files             = ["lib/codegraph.rb","bin/codegraph"] + ["gemspec","LICENSE"]
  s.bindir            = 'bin'
  s.executables       = ['codegraph']
  s.require_path      = 'lib'

  s.add_dependency('graph')
  s.add_dependency('jobQueue')
  s.add_dependency('ascii')
  s.add_development_dependency('rake')

  s.author            = "Ralf Mueller"
  s.email             = "stark.dreamdetective@gmail.com"
  s.homepage          = "http://codegraph.rubyforge.org"
  s.rubyforge_project = "codegraph"
  s.licenses          = ['BSD']

  s.has_rdoc          = true
  s.rdoc_options << '--title' << 'codegraph -- The Code Analysis Tool -- Documentation'
end

# vim:ft=ruby
