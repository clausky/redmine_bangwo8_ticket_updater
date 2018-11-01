require 'redmine'
require 'rest-client'
require 'json'

class Bangwo8Listener < Redmine::Hook::Listener
    @@account = nil
    @@password = nil
    @@issue = nil
    @@param = nil

    def controller_issues_edit_after_save(context)
        load_config
        @@issue = context[:issue]

        ticketId = get_field("工单ID").to_i
        return unless ticketId > 0
        Thread.new do
            data = get_fields
            RAILS_DEFAULT_LOGGER.info "Bangwo8Listener update ticket(#{ticketId}):" + data.to_json()
            RAILS_DEFAULT_LOGGER.info RestClient.put "http://#{@@account}:#{@@password}@www.bangwo8.com/api/v1/tickets/#{ticketId}.json",data.to_json(),{content_type: "application/json"}
        end
    end

    def load_config()
        @@account = Setting.plugin_redmine_bangwo8_ticket_updater['bangwo8_username']
        @@password = Setting.plugin_redmine_bangwo8_ticket_updater['bangwo8_password']
    end

    def get_fields()
        statusMap = Hash[
            "研发完成" => 3,
            "测试完成" => 3,
            "已上线"    => 4,
            "已关闭"   => 5,
        ]
        priorityLevel = get_field("priority_id").to_i
        priorityLevel = 4 if priorityLevel == 5

        ticket = get_ticket(get_field("工单ID").to_i)
        ticket.delete("ticketId")
        #ticket.delete("ticketSource")
        ticket["subject"] = get_field("subject");
        ticket["descript"] = get_field("description");
        ticket["ticketStatus"] = statusMap[@@issue.status.name];
        ticket["priorityLevel"] = priorityLevel;
        ticket["ticketReply"] = {:replyMsg=>get_notes()};

        ticket["custom_fields"] = ticket["custom_fields"].map { |f|
            f["value"] = get_field("需求方期望完成时间") if f["key"] == "expect_time";
            f["value"] = get_field("due_date") if f["key"] == "plan_time";
            f["value"] = get_field("负责产品经理") if f["key"] == "pm";
            f["value"] = @@issue.status.name if f["key"] == "xqzt";
            f
        }
        RAILS_DEFAULT_LOGGER.info "Bangwo8Listener update ticket:" + ticket.to_json
        fields = { "ticket" => ticket }
        return fields
    end

    def get_field(field_name)
        return get_custom_field(field_name) unless exists_on_issue?(field_name)
        return get_notes if field_name == 'notes'

        expression = '@@issue'
        field_name.split('.').each {|s| expression += ".send(:#{s})" }

        return eval(expression)
    end

    def exists_on_issue?(field_name)
        return (@@issue.respond_to?(field_name.to_sym()) ||
                 @@issue.respond_to?(field_name.split('.')[0].to_sym())) 
    end

    def get_custom_field(field_name)
        field = @@issue.custom_field_values.detect {|v| v.custom_field.name == field_name }

        return field ? field.value : nil
    end

    def get_notes()
        note = ""
        @@issue.send(:journals).each do |j|
            note = j[:notes]
        end
        return note
    end

    def get_ticket(ticketId)
        ticket_raw = JSON.parse RestClient.get "http://#{@@account}:#{@@password}@www.bangwo8.com/api/v1/tickets/#{ticketId}.json"
        return 0 if ticket_raw['ticket'].nil?
        ticket = ticket_raw['ticket'].first
        return ticket
    end
end
