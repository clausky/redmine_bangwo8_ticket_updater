require 'rest-client'
require 'json'

class Bangwo8TicketController < ApplicationController
    unloadable

    before_action :get_ticket, :only => [:new]
    accept_api_auth :new

    @@ticket = nil

    def new
        if @@ticket.nil?
            render_404 :json => {:msg => "ticket not found"}
            return
        end
        if CustomValue.where(:custom_field_id => get_custom_field_id("����ID"),:value => @@ticket["ticketId"].to_i).exists?
           render :json => {:msg => "issues is created"}
           return
        end

        status_id = 1  #�½�
        case @@ticket["ticketStatus"].to_i
        when 3 then status_id = 14    #�з����
        when 4 then status_id = 4     #������
        when 5 then status_id = 5     #�ѹر�
        end

        project_id = "bw8-backlog"  #�����
        case get_ticket_custom_field("module").to_i
        when 68958 then project_id = "ticketpro"           #����
        when 68961 then project_id = "bangwoba-gongdan2"   #����ƽ̨
        when 68964 then project_id = "bangwoba-app"        #APP
        when 68967 then project_id = "bangwoba-im"         #IM
        when 68970 then project_id = "pc"                  #PC��
        when 68973 then project_id = "bangwoba-callcenter" #��������
        end
        issue_data = {:issue => {
            :subject => @@ticket["subject"],
            :description => @@ticket["descript"],
            :status_id => status_id,       #require
            :priority_id => @@ticket["priorityLevel"].to_i == 0 ? 1 : @@ticket["priorityLevel"].to_i, #require
            :project_id => project_id,
            :due_date => get_ticket_custom_field("plan_time"),
            :custom_fields => [
                {:id => get_custom_field_id("������Դ�ͻ�"),:value => "�Ҳ�֪��"}, #require
                {:id => get_custom_field_id("�����������ʱ��"),:value => get_ticket_custom_field("expect_time")},
                {:id => get_custom_field_id("�����Ʒ����"),:value => get_ticket_custom_field("pm")},
                {:id => get_custom_field_id("����ID"),:value => @@ticket["ticketId"].to_i},
            ],
        }}
        
        ret = RestClient.post "http://127.0.0.1:3000/issues.json",issue_data.to_json,{content_type: "application/json",Authorization: request.headers[:Authorization].to_s} {|response, request, result| response }

        respond_to do |format|
            #format.api
            format.json { render :json => ret }
        end
    end

    def get_ticket_custom_field(field_name)
        field  = @@ticket["custom_fields"].detect {|v| v["key"] == field_name }
        return field ? field["value"] : nil
    end

    def get_custom_field_id(field_name)
        @_customFields = CustomField.all if @_customFields.nil?
        field = @_customFields.detect {|v| v.name == field_name}
        return field ? field.id : nil
    end

    def get_ticket()
        ticketId = params[:ticketId].to_i
        return unless ticketId > 0
        account = Setting.plugin_redmine_bangwo8_ticket_updater['bangwo8_username']
        password = Setting.plugin_redmine_bangwo8_ticket_updater['bangwo8_password']
        ticket_raw = JSON.parse RestClient.get "http://#{account}:#{password}@www.bangwo8.com/api/v1/tickets/#{ticketId}.json"
        @@ticket = ticket_raw['ticket'].first unless ticket_raw['ticket'].nil?
        RAILS_DEFAULT_LOGGER.info "Bangwo8TicketController get ticket(#{ticketId}):" + @@ticket.to_json
    end
end