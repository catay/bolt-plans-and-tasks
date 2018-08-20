#!/opt/puppetlabs/puppet/bin/ruby

require 'json'
require 'open3'
require 'puppet'

# functions

def do_yum(action)
  cmd = ['yum', '-y', '-q']

  case action
  when 'update'
    cmd << action
    update(*cmd)

  when 'has-updates'
    cmd << 'check-update'
    updates?(*cmd)

  end
end

def update(*cmd)
  stdout, stderr, status = Open3.capture3(*cmd)
  raise Puppet::Error, stderr unless status.success?

  { status: stdout.strip }
end

def updates?(*cmd)
  stdout, stderr, status = Open3.capture3(*cmd)

  case status.exitstatus
  when 0
    stdout = false
  when 100
    stdout = true
  else
    raise Puppet::Error, stderr unless status.success?
  end

  { status: stdout }
end

# main

params = JSON.parse(STDIN.read)
action = params['action']

begin
  result = do_yum(action)
  puts result.to_json
  exit 0
rescue Puppet::Error => e
  puts({ status: 'failure', error: e.message }.to_json)
  exit 1
end
