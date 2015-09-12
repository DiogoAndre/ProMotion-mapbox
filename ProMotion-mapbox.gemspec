# -*- encoding: utf-8 -*-
Gem::Specification.new do |spec|
  spec.name          = "ProMotion-mapbox"
  spec.version       = "0.2.0"
  spec.authors       = ["Diogo Andre"]
  spec.email         = ["diogo@regattapix.com"]
  spec.description   = %q{Adds PM::MapScreen support to ProMotion, using Mapbox as map provider.}
  spec.summary       = %q{Adds PM::MapScreen support to ProMotion, using Mapbox as map provider. Forked from Promotion-map}
  spec.homepage      = "https://github.com/diogoandre/ProMotion-mapbox"
  spec.license       = "MIT"

  files = []
  files << 'README.md'
  files.concat(Dir.glob('lib/**/*.rb'))
  spec.files         = files
  spec.test_files    = spec.files.grep(%r{^(spec)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "ProMotion", "~> 2.0"
  spec.add_runtime_dependency "motion-cocoapods"
  spec.add_development_dependency "motion-stump", "~> 0.3"
  spec.add_development_dependency "motion-redgreen", "~> 0.1"
  spec.add_development_dependency "motion_print"
  spec.add_development_dependency "rake"
end
