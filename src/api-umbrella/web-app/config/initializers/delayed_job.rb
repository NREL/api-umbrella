Delayed::Worker.destroy_failed_jobs = false

if(Rails.env.test?)
  # Check for jobs more frequently in the test environment to cut down on wait
  # times for integration tests.
  Delayed::Worker.sleep_delay = 0.2
end
