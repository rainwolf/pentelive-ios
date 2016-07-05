post_install do |installer|
  require 'fileutils'
  FileUtils.cp_r('Pods/Target Support Files/Pods/Pods-Acknowledgements.plist', 'test1/Settings.bundle/Acknowledgements.plist', :remove_destination => true)
end

source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '7.0'
pod 'Firebase/Core'
pod 'Firebase/AdMob'
pod 'TSMessages', :git => 'https://github.com/rainwolf/TSMessages.git'
pod 'PopoverView'
pod 'SVWebViewController', :head
pod "Color-Picker-for-iOS", "~> 2.0"

