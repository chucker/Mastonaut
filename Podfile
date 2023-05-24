# Uncomment the next line to define a global platform for your project
platform :macos, '10.13'

target 'Mastonaut' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

	project 'Mastonaut.xcodeproj'

  # Pods for Mastonaut
  pod 'MastodonKit', :path => 'Dependencies/MastodonKit'
  pod 'Starscream', '~> 3.1.0'
  pod 'SVGKit'

  plugin 'cocoapods-acknowledgements'

  target 'MastonautTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'Mastonaut (Mock)' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'CoreTootin' do
    inherit! :search_paths
    # Pods for testing
  end

end

target 'QuickToot' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

	project 'Mastonaut.xcodeproj'

  # Pods for Mastonaut
  pod 'MastodonKit', :path => 'Dependencies/MastodonKit'
  pod 'Starscream', '~> 3.1.0'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['LD_NO_PIE'] = 'NO'
        end
    end
end
