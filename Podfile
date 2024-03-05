# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'TalkSocial' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for TalkSocial
  pod 'PINRemoteImage'
  pod 'RealmSwift', '~>10'
  pod 'ToastViewSwift'

end


post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
    end
  end
end
