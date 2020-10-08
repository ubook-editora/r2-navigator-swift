Pod::Spec.new do |s|

  s.name         = "R2Navigator"
  s.version      = "2.0.0-alpha.1-fix.3"
  s.license      = "BSD 3-Clause License"
  s.summary      = "R2 Navigator"
  s.swift_version = '5.0'
  s.homepage     = "http://readium.github.io"
  s.author       = { "Aferdita Muriqi" => "aferdita.muriqi@gmail.com" }
  s.source       = { :git => "https://github.com/ubook-editora/r2-navigator-swift.git", :tag => "2.0.0-alpha.1-fix.3" }
  s.exclude_files = ["**/Info*.plist"]
  s.requires_arc = true
  s.resources    = ['r2-navigator-swift/Resources/**', 'r2-navigator-swift/EPUB/Resources/**']
  s.source_files  = "r2-navigator-swift/**/*.{m,h,swift}"
  s.platform     = :ios
  s.ios.deployment_target = "10.0"

  s.dependency 'R2Shared', '2.0.0-alpha.1-fix.3'
  s.dependency 'SwiftSoup', '2.3.2'
  
end
