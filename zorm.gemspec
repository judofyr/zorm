# encoding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib)
require 'zorm/version'

Gem::Specification.new do |gem|
  gem.name          = "zorm"
  gem.version       = Zorm::VERSION
  gem.authors       = ["Magnus Holm"]
  gem.email         = ["judofyr@gmail.com"]
  gem.summary       = %q{My little ORM}
  gem.description   = gem.summary
  gem.homepage      = "http://judofyr.github.com/zorm"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end

