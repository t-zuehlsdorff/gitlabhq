module StorageHealthHelper
  def failing_storage_health_message(storage_health)
    storage_name = content_tag(:strong, h(storage_health.storage_name))
    host_names = h(storage_health.failing_on_hosts.to_sentence)
    translation_params = { storage_name: storage_name,
                           host_names: host_names,
                           failed_attempts: storage_health.total_failures }

    translation = n_('%{storage_name}: failed storage access attempt on host:',
                     '%{storage_name}: %{failed_attempts} failed storage access attempts:',
                     storage_health.total_failures) % translation_params

    translation.html_safe
  end

  def message_for_circuit_breaker(circuit_breaker)
    maximum_failures = circuit_breaker.failure_count_threshold
    current_failures = circuit_breaker.failure_count
    permanently_broken = circuit_breaker.circuit_broken? && current_failures >= maximum_failures

    translation_params = { number_of_failures: current_failures,
                           maximum_failures: maximum_failures,
                           number_of_seconds: circuit_breaker.failure_wait_time }

    if permanently_broken
      s_("%{number_of_failures} of %{maximum_failures} failures. GitLab will not "\
         "retry automatically. Reset storage information when the problem is "\
         "resolved.") % translation_params
    elsif circuit_breaker.circuit_broken?
      _("%{number_of_failures} of %{maximum_failures} failures. GitLab will "\
        "block access for %{number_of_seconds} seconds.") % translation_params
    else
      _("%{number_of_failures} of %{maximum_failures} failures. GitLab will "\
        "allow access on the next attempt.") % translation_params
    end
  end
end
