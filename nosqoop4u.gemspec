Gem::Specification.new do |s|
  s.name = 'nosqoop4u'
  s.rubyforge_project = 'nosqoop4u'
  s.platform = 'java'
  s.version = '0.1.2'
  s.date = '2011-07-15'
  s.authors = ["Frank Fejes"]
  s.email = 'frank@fejes.net'
  s.summary =
    'A sqoop-like jruby/jdbc query app that does not run via map/reduce.'
  s.homepage = 'https://github.com/fsfiii/nosqoop4u'
  s.description = <<EOF
A sqoop-like jruby/jdbc query application that does not run via map/reduce.
It supports direct output to HDFS and unix filesystems as well as STDOUT.
Requires jruby 1.6+.
EOF
  s.files = [
    "README",
    "CHANGELOG",
    "bin/nosqoop4u",
    "bin/nosqoop4u.rb",
  ]
  s.executables = [
    "nosqoop4u",
    "nosqoop4u.rb",
  ]
  s.post_install_message = <<EOF
===
  Please be sure to install with:

  jgem install --no-wrapper nosqoop4u
===
EOF
end
