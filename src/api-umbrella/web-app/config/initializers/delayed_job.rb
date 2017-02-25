# Exit immediately when the delayed_job process receives a kill signal.
#
# This prevents some race conditions that can lead to API Umbrella stopping
# taking a long time. If mongo is running on the same server and mongo exits
# first, then without exiting immediately, delayed_job can get stuck waiting
# for a new mongo primary (until the 30s server_selection_timeout is hit)
# before exiting.
Delayed::Worker.raise_signal_exceptions = :term

# Keep failed jobs in the database.
Delayed::Worker.destroy_failed_jobs = false

if(Rails.env.test?)
  # Check for jobs more frequently in the test environment to cut down on wait
  # times for integration tests.
  Delayed::Worker.sleep_delay = 0.2
end
