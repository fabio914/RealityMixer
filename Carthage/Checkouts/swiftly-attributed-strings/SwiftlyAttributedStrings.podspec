
Pod::Spec.new do |s|

  s.name         = "SwiftlyAttributedStrings"
  s.version      = "2.0.0"
  s.summary      = "Harness the power of Swift syntax to swiftly create Attributed Strings."
  s.description  = "Swiftly Attributed Strings uses most of the Swift syntactic sugar to provide an easier way to instantiate NSAttributedStrings"
  s.homepage     = "https://github.com/fabio914/swiftly-attributed-strings"
  
  s.license      = "MIT"
  
  s.author             = "Fabio Dela Antonio"
  s.social_media_url   = "https://fabio914.blogspot.com/"
  
  s.platform     = :ios, "10.3"
  
  s.source       = { :git => "https://github.com/fabio914/swiftly-attributed-strings.git", :tag => "#{s.version}" }

  s.source_files  = "SwiftlyAttributedStrings", "SwiftlyAttributedStrings/**/*.{h,m,swift}"
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5' }

end
