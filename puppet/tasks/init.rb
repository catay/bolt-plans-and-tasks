#!/opt/puppetlabs/puppet/bin/ruby

require 'json'
require 'open3'
require 'puppet'

# classes
# code based on MCollective Puppet Agent.
# https://github.com/puppetlabs/mcollective-puppet-agent
class PuppetAgentMgr
  def initialize(config_file = nil)
    # set puppet agent run mode to agent
    Puppet.settings.preferred_run_mode = :agent

    # use custom config if provided, if not use default
    args = []
    (args << "--config=#{config_file}") if config_file

    Puppet.settings.initialize_global_settings(args)
    Puppet.settings.initialize_app_defaults(
      Puppet::Settings.app_defaults_for_run_mode(Puppet.run_mode)
    )
  end

  def status
    status = {
      disabled: disabled?,
      enabled: !disabled?,
      applying: applying?,
      disable_message: disable_message
    }
    status
  end

  # enable the puppet agent
  def enable!
    File.unlink(Puppet[:agent_disabled_lockfile]) if disabled?
    status
  end

  # disable the puppet agent
  def disable!(msg = nil)
    if enabled?
      msg ||= "Disabled by Puppet task on #{Time.now.strftime('%c')}"
      File.write(Puppet[:agent_disabled_lockfile],
                 JSON.dump(disabled_message: msg))
    end

    status
  end

  # get disable message
  def disable_message
    msg = if disabled?
            JSON.parse(File.read(Puppet[:agent_disabled_lockfile]))
          else
            { disabled_message: nil }
          end

    msg['disabled_message']
  end

  # check if puppet agent is enabled
  def enabled?
    !disabled?
  end

  # check if puppet agent is disabled
  def disabled?
    File.exist?(Puppet[:agent_disabled_lockfile])
  end

  # check if puppet agent run is in progress
  def applying?
    return false unless File.exist?(Puppet[:agent_catalog_run_lockfile])
    true
  end
end

# functions

def puppet_agent(action)
  p = PuppetAgentMgr.new

  case action
  when 'status'
    stdout = p.status
  when 'disable'
    stdout = p.disable!
  when 'enable'
    stdout = p.enable!
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
