source "https://cdn.cocoapods.org/"

# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

target 'app' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for app

  # Network	
  pod 'Alamofire', '~> 5.9.1'
  pod 'Moya', '~> 15.0.0'
  pod 'Moya/RxSwift'
  pod 'RxCocoa', '~> 6.7.1'

  # Tools
  pod 'SwiftLint', '~> 0.56.1'
  pod 'SwiftyBeaver', '~> 1.9.5'

  #DI
  pod 'Swinject'

  #UI
  pod 'Toast-Swift', '~> 5.1'
  pod 'SVProgressHUD', '~> 2.3'
  pod 'IQKeyboardManagerSwift', '~> 7.1.1'

  pod 'FMDB'
  pod 'KeychainAccess'

  target 'appTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'appUITests' do
    # Pods for testing
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    if target.name == 'RxSwift'
        target.build_configurations.each do |config|
            if config.name.include?('Debug')
                config.build_settings['OTHER_SWIFT_FLAGS'] ||= ['-D', 'TRACE_RESOURCES']
            end
        end
    end
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ""
      config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
      config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
    end
  end
end
