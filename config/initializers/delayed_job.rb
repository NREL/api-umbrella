# Don't keep around failed jobs, since we don't want to retry failed
# deployments (since a new job that replaces it may have come in in the
# meantime).
Delayed::Worker.destroy_failed_jobs = true
