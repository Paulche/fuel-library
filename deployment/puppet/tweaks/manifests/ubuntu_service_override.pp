define tweaks::ubuntu_service_override (
  $service_name = $name,
  $package_name = $name,
) {
  if $::operatingsystem == 'Ubuntu' {
    $override_file = "/etc/init/${service_name}.override"
    $exec_create_name     = "create_${service_name}_override"
    $exec_remove_name     = "remove_${service_name}_override"
    
    exec { $exec_create_name :
      path    => [ '/sbin', '/bin', '/usr/bin', '/usr/sbin' ],
      command => "echo 'manual' > ${override_file}",
      unless  => "dpkg -l ${package_name}",
    } 
    
    exec { $exec_name :
      path    => [ '/sbin', '/bin', '/usr/bin', '/usr/sbin' ],
      command => "rm -f ${override_file}",
      onlyif  => "test -f ${override_file}",
    }

    Exec[$exec_create_name] -> Package <| name == $package_name |> -> Exec[$exec_remove_name]
    Exec[$exec_create_name] -> Package <| title == $package_name |> -> Exec[$exec_remove_name]
    Exec[$exec_create_name] -> Exec[$exec_remove_name]
    Exec[$exec_remove_name] -> Service <| name == $service_name |>
    Exec[$exec_remove_name] -> Service <| title == $service_name |>
  }
}
