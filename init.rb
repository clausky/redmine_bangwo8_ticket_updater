require 'redmine'
require File.dirname(__FILE__) + '/lib/bangwo8'

RAILS_DEFAULT_LOGGER = Rails.logger unless defined? RAILS_DEFAULT_LOGGER
RAILS_DEFAULT_LOGGER.info 'Starting redmine_bangwo8_ticket_updater Hooks'

Redmine::Plugin.register :redmine_bangwo8_ticket_updater do
  name 'Redmine Bangwo8 Ticket Updater'
  author 'Clausky'
  description 'Updates associated Bangwo8 tickets when Redmine issues are updated'
  version '0.0.1'
  settings :default => {:default => {'empty' => true}} , :partial => 'settings/bangwo8_plugin_settings'
end
