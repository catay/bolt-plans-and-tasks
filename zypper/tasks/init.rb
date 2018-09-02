#!/opt/puppetlabs/puppet/bin/ruby

require 'json'
require 'open3'
require 'puppet'

# functions

def do_zypper(action)
  cmd = ['zypper', '-q']

  case action
  when 'update'
    cmd << action
    update(*cmd)

  when 'has-updates'
    cmd << 'patch-check'
    updates?(*cmd)

  end
end

def update(*cmd)
  cmd << '-y'
  # check the zypper man page for more info about the exit codes
  valid_exit_codes = [0, 102, 103]
  stdout, stderr, status = Open3.capture3(*cmd)

  raise Puppet::Error, stderr unless
    valid_exit_codes.include?(status.exitstatus)

  { status: stdout.strip }
end

def updates?(*cmd)
  stdout, stderr, status = Open3.capture3(*cmd)

  case status.exitstatus
  when 0
    stdout = false
  when 100, 101
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
  result = do_zypper(action)
  puts result.to_json
  exit 0
rescue Puppet::Error => e
  puts({ status: 'failure', error: e.message }.to_json)
  exit 1
end
