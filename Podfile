project 'JustALine.xcodeproj'

# Uncomment the next line to define a global platform for your project
platform :ios, '11.3'

def pods_all_targets
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!
  pod 'lottie-ios'
  pod 'Reachability', '~> 3.2'

  # Pods for Pairing
  pod 'Firebase', '~> 4.10'
  pod 'FirebaseAuth'
  pod 'FirebaseCrash', '~> 2.0'
  pod 'FirebaseAnalytics', '~> 4.1'
  pod 'FirebaseDatabase', '~> 4.1'
  pod 'NearbyMessages'

  # Pods for GoogleAR frameworks
  pod 'ARCore', '~> 1.2.0'
  pod 'GTMSessionFetcher/Core', '~> 1.1'
  pod 'GoogleToolboxForMac/Logger', '~> 2.1'
  pod 'GoogleToolboxForMac/NSData+zlib', '~> 2.1'
  pod 'Protobuf', '~> 3.5'
  pod 'gRPC-ProtoRPC', '~> 1.0'
end

target 'JustALine' do
    pods_all_targets
    
    target 'JustALineTests' do
        inherit! :search_paths
        # Pods for testing
    end
end

target 'JustALine Global' do
    pods_all_targets
end

# Addresses bug with XCode 9 and app icons https://github.com/CocoaPods/CocoaPods/issues/7003
post_install do |installer|
    copy_pods_resources_path = "Pods/Target Support Files/Pods-JustALine/Pods-JustALine-resources.sh"
    copy_pods_global_resources_path = "Pods/Target Support Files/Pods-JustALine Global/Pods-JustALine Global-resources.sh"
    string_to_replace = '--compile "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"'
    assets_compile_with_app_icon_arguments = '--compile "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}" --app-icon "${ASSETCATALOG_COMPILER_APPICON_NAME}" --output-partial-info-plist "${BUILD_DIR}/assetcatalog_generated_info.plist"'
    text = File.read(copy_pods_resources_path)
    new_contents = text.gsub(string_to_replace, assets_compile_with_app_icon_arguments)
    File.open(copy_pods_resources_path, "w") {|file| file.puts new_contents }
    
    text = File.read(copy_pods_global_resources_path)
    new_contents = text.gsub(string_to_replace, assets_compile_with_app_icon_arguments)
    File.open(copy_pods_global_resources_path, "w") {|file| file.puts new_contents }

end
