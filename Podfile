source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '9.0'
project 'Xcode/Awful'

inhibit_all_warnings!
use_frameworks!
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

target 'Awful' do
  pod '1PasswordExtension'
  pod 'AFNetworking', '~> 2.0'
  pod 'ARChromeActivity'
  pod 'Crashlytics'
  pod 'FLAnimatedImage'
  pod 'GRMustache'
  #pod 'GRMustache.swift' # Waiting for Swift 4 support
  pod 'GRMustache.swift', :git => 'https://github.com/chrisballinger/GRMustache.swift', :branch => 'feature/swift4'


  pod 'HTMLReader'
  pod 'ImgurAnonymousAPIClient'
  pod 'JLRoutes'
  pod 'KVOController'
  pod 'MRProgress/Overlay'
  
  # Fixes a compile error; I'm happy to pin to some subsequent tagged version if that ever happens.
  pod 'PSMenuItem', :git => 'https://github.com/steipete/PSMenuItem', :commit => '489dbb1c42f8c2c43ac04f0a34faf9aea3b7aa79'
  
  # Swift 4 support that doesn't crash in KVO. Go back to main pod when it arrives there
  pod 'PullToRefresher', :git => 'https://github.com/MindSea/PullToRefresh', :branch => 'fix-simultaneous-access'
  
  pod 'TUSafariActivity'
  pod 'WebViewJavascriptBridge'
end

target 'Core' do
  pod 'HTMLReader'
  pod 'OMGHTTPURLRQ'
  pod 'PromiseKit'
  
  target 'CoreTests' do
    inherit! :search_paths
  end
end

target :Smilies do
  pod 'FLAnimatedImage'
  pod 'HTMLReader'
  
  target :SmiliesTests do
    inherit! :search_paths
  end
end

target :SmilieExtractor do
  pod 'FLAnimatedImage'
  pod 'HTMLReader'
end
