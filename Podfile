source 'https://cdn.cocoapods.org/'
platform :ios, '17.0'
install! 'cocoapods', :deterministic_uuids => true

target 'SprintAI' do
  use_frameworks!
  pod 'MediaPipeTasksVision', '0.10.18'

  target 'SprintAIIntegrationTests' do
    inherit! :search_paths
  end
end

# MediaPipe 0.10.18 propagates graph force-load flags to hosted tests even with
# search-path-only inheritance. The host already links the graph. Remove only
# those generated test flags so the bundle uses its host's MediaPipe symbols.
post_integrate do |_installer|
  Dir.glob('Pods/Target Support Files/Pods-SprintAIIntegrationTests/*.xcconfig').each do |path|
    lines = File.readlines(path).reject { |line| line.start_with?('OTHER_LDFLAGS[sdk=') }
    File.write(path, lines.join)
  end
end
