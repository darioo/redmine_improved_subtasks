require 'redmine'

require_dependency 'improved_subtasks/patches/issue_patch'

Redmine::Plugin.register :redmine_improved_subtasks do
  
  name 'Redmine Improved ParentTask behavior in subtasks structure'
  author 'Dariusz Kowalski'
  description 'This plugin change default behavior of priorities, start and due date at parent tasks in sub-tasks structure'
  version '0.0.1' 
  author_url 'https://github.com/darioo'
  url "https://github.com/darioo/redmine_improved_subtasks" if respond_to?(:url)
end
