post_install do |installer|
  require 'fileutils'
  FileUtils.cp_r('Pods/Target Support Files/Pods-penteLive/Pods-penteLive-Acknowledgements.plist', 'test1/Settings.bundle/Acknowledgements.plist', :remove_destination => true)
end

source 'https://github.com/CocoaPods/Specs.git'

target "penteLive" do
platform :ios, '7.0'
	pod 'Firebase/Core'
	pod 'Firebase/AdMob'
	pod 'TSMessages', :git => 'https://github.com/rainwolf/TSMessages.git'
	pod 'PopoverView'
	pod 'SVWebViewController'
	pod "Color-Picker-for-iOS", "~> 2.0"
	pod "UIColor+Hex"
	pod 'ICDMaterialActivityIndicatorView'
	pod 'RMStore', '~> 0.7'
end
