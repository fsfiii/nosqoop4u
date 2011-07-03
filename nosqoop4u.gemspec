Gem::Specification.new do |s|
  s.name = 'nosqoop4u'
  s.rubyforge_project = 'nosqoop4u'
  s.platform = 'java'
  s.version = '0.0.1'
  s.date = '2011-07-02'
  s.authors = ["Frank Fejes"]
  s.email = 'frank@fejes.net'
  s.summary =
    'A sqoop-like jruby/jdbc application that does not run via map/reduce.'
  s.homepage = 'https://github.com/fsfiii/nosqoop4u'
  s.description =
    "A sqoop-like jruby/jdbc application that does not run via map/reduce.\n" +
    'Requires jruby 1.6+.'
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
