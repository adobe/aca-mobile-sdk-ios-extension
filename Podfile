# Uncomment the next line to define a global platform for your project
platform :ios, '12.0'

# Comment the next line if you don't want to use dynamic frameworks
use_frameworks!

workspace 'AEPContentAnalytics'
project 'AEPContentAnalytics.xcodeproj'

pod 'SwiftLint', '0.52.0'

def core_pods
    pod 'AEPCore', '~> 5.0'
    pod 'AEPServices', '~> 5.0'
    pod 'AEPEdge', '~> 5.0'
end

target 'AEPContentAnalytics' do
    core_pods
end

target 'AEPContentAnalyticsTests' do
    core_pods
end

post_install do |pi|
    pi.pods_project.targets.each do |t|
        t.build_configurations.each do |bc|
            bc.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
            bc.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
        end
    end
end
