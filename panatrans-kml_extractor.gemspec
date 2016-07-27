# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'panatrans/kml_extractor/version'

Gem::Specification.new do |spec|
  spec.name          = "panatrans-kml_extractor"
  spec.version       = Panatrans::KmlExtractor::VERSION
  spec.authors       = ["merlos"]
  spec.email         = ["jmmerlos@merlos.org"]

  spec.summary       = %q{Helper gem for panatrans. Converts Mibus export KML to GTFS}
  spec.description   = %q{Helper gem to convert an export of mibus KML to GTFS}
  spec.homepage      = "http://github.com/merlos/panatrans-kml-extractor"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"

  spec.add_dependency "nokogiri"
  spec.add_dependency "open-uri"
  spec.add_dependency "pp"
  spec.add_dependency "cross-track-distance","~>1.0.0"
end
