# by claude
# Drops the widget extension from the project, so a build where only the extension fails still ships the app.
# The app's widget code is compiled only with NAMIDA_WIDGETS, removing the flag leaves it out with the extension.
#
#   ruby ios/scripts/remove_widget_extension.rb
require 'xcodeproj'

project_path = File.expand_path('../Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |t| t.name == 'Runner' }
abort('no Runner target') if runner.nil?

widgets = project.targets.find { |t| t.name == 'NamidaWidgets' }
if widgets
  runner.dependencies.select { |d| d.target == widgets }.each(&:remove_from_project)
  appex = widgets.product_reference
  runner.copy_files_build_phases.each do |phase|
    phase.files.select { |f| f.file_ref == appex }.each { |f| phase.remove_build_file(f) }
  end
  appex&.remove_from_project
  widgets.remove_from_project
end

runner.build_configurations.each do |config|
  conditions = config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']
  next if conditions.nil?

  kept = conditions.split.reject { |c| c == 'NAMIDA_WIDGETS' }
  config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = kept.join(' ')
end

project.save
puts 'removed the widget extension'
