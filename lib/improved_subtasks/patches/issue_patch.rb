module ImprovedSubtasks
  module Patches
    module IssuePatch
      unloadable
      
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)
        base.class_eval do
        end
      end
      
      module ClassMethods
      end
      
      module InstanceMethods

        # Safely sets attributes
        # Should be called from controllers instead of #attributes=
        # attr_accessible is too rough because we still want things like
        # Issue.new(:project => foo) to work
        def safe_attributes=(attrs, user=User.current)
          return unless attrs.is_a?(Hash)

          attrs = attrs.dup

          # Project and Tracker must be set before since new_statuses_allowed_to depends on it.
          if (p = attrs.delete('project_id')) && safe_attribute?('project_id')
            if allowed_target_projects(user).where(:id => p.to_i).exists?
              self.project_id = p
            end
          end

          if (t = attrs.delete('tracker_id')) && safe_attribute?('tracker_id')
            self.tracker_id = t
          end

          if (s = attrs.delete('status_id')) && safe_attribute?('status_id')
            if new_statuses_allowed_to(user).collect(&:id).include?(s.to_i)
              self.status_id = s
            end
          end

          attrs = delete_unsafe_attributes(attrs, user)
          return if attrs.empty?

          unless leaf?
            # changed 
            attrs.reject! {|k,v| %w(done_ratio estimated_hours).include?(k)}
          end

          if attrs['parent_issue_id'].present?
            s = attrs['parent_issue_id'].to_s
            unless (m = s.match(%r{\A#?(\d+)\z})) && (m[1] == parent_id.to_s || Issue.visible(user).exists?(m[1]))
              @invalid_parent_issue_id = attrs.delete('parent_issue_id')
            end
          end

          if attrs['custom_field_values'].present?
            editable_custom_field_ids = editable_custom_field_values(user).map {|v| v.custom_field_id.to_s}
            # TODO: use #select when ruby1.8 support is dropped
            attrs['custom_field_values'] = attrs['custom_field_values'].reject {|k, v| !editable_custom_field_ids.include?(k.to_s)}
          end

          if attrs['custom_fields'].present?
            editable_custom_field_ids = editable_custom_field_values(user).map {|v| v.custom_field_id.to_s}
            # TODO: use #select when ruby1.8 support is dropped
            attrs['custom_fields'] = attrs['custom_fields'].reject {|c| !editable_custom_field_ids.include?(c['id'].to_s)}
          end

          # mass-assignment security bypass
          assign_attributes attrs, :without_protection => true
        end



         def recalculate_attributes_for(issue_id)
            if issue_id && p = Issue.find_by_id(issue_id)
              # priority = highest priority of children
              
              # Changed
              # TODO: change from Settings (global and project)
              #
              # ORGINAL:
              #if priority_position = p.children.joins(:priority).maximum("#{IssuePriority.table_name}.position")
              #  p.priority = IssuePriority.find_by_position(priority_position)
              #end

              # start/due dates = lowest/highest dates of children
              
               # Changed
              # TODO: change from Settings (global and project)
              #
              # ORGINAL:
              #p.start_date = p.children.minimum(:start_date)
              #p.due_date = p.children.maximum(:due_date)
              
              p.start_date = [p.children.minimum(:start_date), p.start_date].min
              p.due_date = [p.children.maximum(:due_date), p.due_date].max

              if p.start_date && p.due_date && p.due_date < p.start_date
                p.start_date, p.due_date = p.due_date, p.start_date
              end

              # done ratio = weighted average ratio of leaves
              unless Issue.use_status_for_done_ratio? && p.status && p.status.default_done_ratio
                leaves_count = p.leaves.count
                if leaves_count > 0
                  average = p.leaves.where("estimated_hours > 0").average(:estimated_hours).to_f
                  if average == 0
                    average = 1
                  end
                  done = p.leaves.joins(:status).
                    sum("COALESCE(CASE WHEN estimated_hours > 0 THEN estimated_hours ELSE NULL END, #{average}) " +
                        "* (CASE WHEN is_closed = #{connection.quoted_true} THEN 100 ELSE COALESCE(done_ratio, 0) END)").to_f
                  progress = done / (average * leaves_count)
                  p.done_ratio = progress.round
                end
              end

              # estimate = sum of leaves estimates
              p.estimated_hours = p.leaves.sum(:estimated_hours).to_f
              p.estimated_hours = nil if p.estimated_hours == 0.0

              # ancestors will be recursively updated
              p.save(:validate => false)
            end
          end


           
      end

    end
  end
end

# require 'dispatcher'
# Dispatcher.to_prepare :redmine_author_notification_emails do
  require_dependency 'issue'
  Issue.send(:include,  ImprovedSubtasks::Patches::IssuePatch)
#end
