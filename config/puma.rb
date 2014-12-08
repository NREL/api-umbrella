# Detach the master process from bundler so things work across deployments:
# https://github.com/puma/puma/blob/master/DEPLOYMENT.md#restarting
prune_bundler
