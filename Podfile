post_install do |installer|
  require 'fileutils'
  FileUtils.cp_r('Pods/Target Support Files/Pods-penteLive/Pods-penteLive-Acknowledgements.plist', 'test1/Settings.bundle/Acknowledgements.plist', :remove_destination => true)
end

source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!
use_modular_headers!

target "penteLive" do
platform :ios, '8.0'
#	use_frameworks!
#	pod 'Firebase/Core'
#	pod 'Firebase/AdMob'
    pod 'Google-Mobile-Ads-SDK'
	pod 'TSMessages', :git => 'https://github.com/rainwolf/TSMessages.git'
	pod 'PopoverView', :git => 'https://github.com/runway20/PopoverView.git'
#	pod 'SVWebViewController', :git => 'https://github.com/TransitApp/SVWebViewController.git'
	pod "Color-Picker-for-iOS", "~> 2.0"
	pod "UIColor+Hex"
	pod 'ICDMaterialActivityIndicatorView'
	pod 'RMStore', '~> 0.7'
	pod 'InAppSettingsKit'
	pod 'NSHash', '~> 1.1.0'
	pod 'CocoaAsyncSocket'
	pod 'UIBarButtonItem-Badge', :git => 'https://github.com/mikeMTOL/UIBarButtonItem-Badge.git'
	pod 'AFWebViewController', '~> 1.0'
	pod 'PersonalizedAdConsent'
end
