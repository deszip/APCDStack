Pod::Spec.new do |s|
  s.name = 'APCDStack'
  s.version = '0.4.0'
  s.license = 'MIT'
  s.summary = 'CoreData stack done right.'
  s.homepage = 'https://github.com/Deszip/APCDStack'
  s.authors = { "Deszip" => "igor@alterplay.com" }
  s.source = { :git => "https://github.com/Deszip/APCDStack.git", :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.9'

  s.source_files = 'Sources/*.swift'

  s.requires_arc = true
end
