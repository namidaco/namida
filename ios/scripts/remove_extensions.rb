# by claude
# Drops the given app extensions from the project, so a build where only extensions fail still ships the app.
# The app's widget code is compiled only with NAMIDA_WIDGETS, removing the widgets extension removes the flag too.
#
#   ruby ios/scripts/remove_extensions.rb NamidaWidgets NamidaShare
require 'xcodeproj'

abort('usage: remove_extensions.rb <extension target>...') if ARGV.empty?

project_path = File.expand_path('../Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |t| t.name == 'Runner' }
abort('no Runner target') if runner.nil?

ARGV.each do |name|
  extension = project.targets.find { |t| t.name == name }
  next if extension.nil?

  runner.dependencies.select { |d| d.target == extension }.each(&:remove_from_project)
  appex = extension.product_reference
  runner.copy_files_build_phases.each do |phase|
    phase.files.select { |f| f.file_ref == appex }.each { |f| phase.remove_build_file(f) }
  end
  appex&.remove_from_project
  extension.remove_from_project
end

if ARGV.include?('NamidaWidgets')
  runner.build_configurations.each do |config|
    conditions = config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']
    next if conditions.nil?

    kept = conditions.split.reject { |c| c == 'NAMIDA_WIDGETS' }
    config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = kept.join(' ')
  end
end

project.save
puts "removed #{ARGV.join(', ')}"
