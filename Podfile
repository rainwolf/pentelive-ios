def patch_afnetworking_private_header(installer)
    # 扫描并移除 AFNetworking 对私有 IPv6 头文件的直接引用，兼容新版 Xcode 的模块校验。
    require 'fileutils'
    afnetworking_dir = File.join(installer.sandbox.pod_dir('AFNetworking'), 'AFNetworking')
    return unless Dir.exist?(afnetworking_dir)
  
    private_header_import = '#import <netinet6/in6.h>'
    Dir.glob(File.join(afnetworking_dir, '**', '*.{h,m}')).each do |file_path|
      next unless File.exist?(file_path)
  
      file_content = File.read(file_path)
      next unless file_content.include?(private_header_import)
  
      original_mode = File.stat(file_path).mode
      File.chmod(original_mode | 0o200, file_path)
      File.write(file_path, file_content.gsub(private_header_import, ''))
      File.chmod(original_mode, file_path)
      puts "patched AFNetworking private header import: #{File.basename(file_path)}"
    end
  end
  
post_install do |installer|
  require 'fileutils'
  patch_afnetworking_private_header(installer)
  FileUtils.cp_r('Pods/Target Support Files/Pods-penteLive/Pods-penteLive-Acknowledgements.plist', 'test1/Settings.bundle/Acknowledgements.plist', :remove_destination => true)
  installer.generated_projects.each do |project|
      project.targets.each do |target|
          target.build_configurations.each do |config|
              config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
           end
      end
  end
end

source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!
use_modular_headers!

target "penteLive" do
platform :ios, '13.0'
#   use_frameworks!
    pod 'TSMessages', :git => 'https://github.com/rainwolf/TSMessages.git'
    pod 'PopoverView', :git => 'https://github.com/runway20/PopoverView.git'
#   pod 'SVWebViewController', :git => 'https://github.com/TransitApp/SVWebViewController.git'
    pod "Color-Picker-for-iOS", "~> 2.0"
    pod "UIColor+Hex"
    pod 'ICDMaterialActivityIndicatorView'
    pod 'RMStore', '~> 0.7'
    pod 'InAppSettingsKit'
    pod 'NSHash', '~> 1.1.0'
    pod 'CocoaAsyncSocket'
    pod 'UIBarButtonItem-Badge', :git => 'https://github.com/rainwolf/UIBarButtonItem-Badge.git'
    pod 'AFWebViewController', '~> 1.0'
    pod 'AFNetworking', '~> 4.0'
end

