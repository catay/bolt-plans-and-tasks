#!/opt/puppetlabs/puppet/bin/ruby

require 'json'
require 'open3'
require 'puppet'

# classes
# code based on MCollective Puppet Agent.
# https://github.com/puppetlabs/mcollective-puppet-agent

class PuppetAgentMgr

  def initialize(config_file = nil)
    unless Puppet.settings.app_defaults_initialized?

      # set puppet agent run mode to agent
      Puppet.settings.preferred_run_mode = :agent

      # use custom config if provided, if not use default
      args = []
      (args << "--config=%s" % config_file) if config_file

      Puppet.settings.initialize_global_settings(args)
      Puppet.settings.initialize_app_defaults(
        Puppet::Settings.app_defaults_for_run_mode(Puppet.run_mode))

    end
  end
  
  def status
    status = {
        :disabled => disabled?,
        :enabled => !disabled?,
        :applying => applying?
    }
    status
  end

  # enable the puppet agent
  def enable!
      File.unlink(Puppet[:agent_disabled_lockfile]) if disabled?
  end

  # disable the puppet agent
  def disable!(msg=nil)
    msg ||= "Disabled by task ## on date"
    File.write(Puppet[:agent_disabled_lockfile], JSON.dump(:disabled_message => msg)) unless disabled?
  end

  # check if puppet agent is disabled
  def disabled?
    return File.exist?(Puppet[:agent_disabled_lockfile])
  end

  # check if puppet agent run is in progress
  def applying?
    return false unless File.exist?(Puppet[:agent_catalog_run_lockfile])
    return true
  end

end

# functions

def puppet_agent(action)
  p = PuppetAgentMgr.new
  stdout = ""

  case action
  when 'status'
    stdout = p.status
  when 'disable'
    p.disable!
    stdout = "disabled"
  when 'enable'
    p.enable!
    stdout = "enabled"
  end

  { status: stdout }
end

# main

params = JSON.parse(STDIN.read)
action = params['action']

begin
  result = puppet_agent(action)
  puts result.to_json
  exit 0
rescue Puppet::Error => e
  puts({ status: 'failure', error: e.message }.to_json)
  exit 1
end
