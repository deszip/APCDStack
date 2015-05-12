Pod::Spec.new do |s|
  s.name             = "APCDStack"
  s.version          = "0.1.0"
  s.summary          = "CoreData stack done right."
  s.description      = <<-DESC
                       Simple class containing multithreaded CoreData stack.
                       DESC
  s.homepage         = "https://github.com/Deszip/APCDStack"
  s.license          = 'MIT'
  s.author           = { "Deszip" => "igor@alterplay.com" }
  s.source           = { :git => "https://github.com/Deszip/APCDStack.git", :tag => s.version.to_s }

  s.platform     = :ios, '8.0'
  s.osx.deployment_target = '10.8'

  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'APCDStack' => ['Pod/Assets/*.png']
  }

  s.frameworks = 'CoreData'
end
