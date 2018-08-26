
plan tools::update(
  TargetSpec $nodes,
) {

  # retrieve facts
  run_plan('facts', nodes => $nodes)

  # set max task retry
  $max_task_retry=10
  $max_wait_time=30

  # initialize status tracking variables on all nodes
  # status can be 'no', 'yes' or 'failed'
  get_targets($nodes).each |$n| { 
    $n.set_var("has_pre_updates", "no")
    $n.set_var("is_updated", "no")
    $n.set_var("reboot", "no")
    $n.set_var("is_rebooted", "no")
    $n.set_var("has_post_updates", "no")
    $n.set_var("uptime_seconds", 0)
  }

  # check if there are package updates
  $r_has_updates = run_task('yum', $nodes, action => 'has-updates', '_catch_errors' => true)

  # mark failed targets for the has_pre_updates variable
  $r_has_updates.error_set.targets.each |$t| {
    $t.set_var("has_pre_updates", "failed")
  }
  
  # mark nodes that have updates pending or not
  $r_has_updates.ok_set.each |$result| {
    if $result.value[status] {
      $result.target.set_var("has_pre_updates", "yes")
    } else {
      $result.target.set_var("has_pre_updates", "no")
    }
  }

  # get nodes pending updates and store them in array
  $nodes_to_update = $r_has_updates.reduce([]) |$memo, $result| {
    if $result.value[status] {
         $memo << $result.target.name
    }
     else {
       $memo
     }
  }

  # invoke a yum update on the nodes pending updates
  #$r_yum_update = run_task('testcode::echo', $nodes_to_update, msg => 'invoke yum update', '_catch_errors' => true)
  $r_yum_update = run_task('yum', $nodes_to_update, action => 'update', '_catch_errors' => true)

  # mark failed targets for the is_updated variable
  $r_yum_update.error_set.targets.each |$t| {
    $t.set_var("is_updated", "failed")
  }

  # mark nodes which got updated successfully
  $r_yum_update.ok_set.targets.each |$t| {
    $t.set_var("is_updated", "yes")
  }

  # get nodes which successfully updated and require a reboot
  $nodes_to_reboot = $r_yum_update.ok_set.names
  
  # capture uptime of the nodes to reboot and store it in a variable
  $r_yum_update.ok_set.targets.each |$t| {
    $t.set_var("uptime_seconds", $t.facts['uptime_seconds'])
  }

  # reboot the nodes with a 5 second delay
  $r_reboot = run_task('reboot', $nodes_to_reboot, timeout => 5, message => "reboot after installing updates", '_catch_errors' => true)
  #$r_reboot = run_task('testcode::echo', $nodes_to_reboot, msg => 'invoke reboot', '_catch_errors' => true)

  # mark failed targets for the reboot variable
  $r_reboot.error_set.targets.each |$t| {
    $t.set_var("reboot", "failed")
  }

  # mark success targets for the reboot variable
  $r_reboot.ok_set.targets.each |$t| {
    $t.set_var("reboot", "yes")
  }

  if get_targets($nodes_to_reboot).count != 0 {
    # start retry loop for healthcheck after reboot
    range("1", $max_task_retry).each |$i| {

      # wait x seconds for the next retry
      run_task('testcode::wait', localhost, seconds => $max_wait_time, '_catch_errors' => true)

      warning("(${i}) Execute healthcheck after reboot")

      # get nodes that didn't reboot yet
      $nodes_not_rebooted = get_targets($nodes_to_reboot).filter |$n| {
        $n.vars['is_rebooted'] == "no"
      }

      # if there are no nodes to reboot anymore or retry limit is reached, break out of the loop.

      if $nodes_not_rebooted.count == 0 or $i == $max_task_retry { 
        break()
      }

      # refresh facts
      run_plan('facts', nodes => $nodes_not_rebooted)

      get_targets($nodes_not_rebooted).each |$t| {
        if $t.vars['uptime_seconds'] > $t.facts['uptime_seconds'] {
          $t.set_var('is_rebooted', "yes")
        }
      }

    }
  }

  notice("OUTPUT REPORT")
  notice("-------------")

  get_targets($nodes).each |$n| { 
    notice("* ${n.name}")
    notice("  updates pending:    ${n.vars['has_pre_updates']}")
    notice("  updates installed:  ${n.vars['is_updated']}")
    notice("  reboot issued:      ${n.vars['reboot']}")
    notice("  rebooted:           ${n.vars['is_rebooted']}")
    notice("  updates pending:    ${n.vars['has_post_updates']}")
  }

}
