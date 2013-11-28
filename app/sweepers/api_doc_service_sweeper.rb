class ApiDocServiceSweeper < ActionController::Caching::Sweeper
  observe ApiDocService

  def after_create(service)
  end

  def after_update(service)
    expire_cache_for(service)
  end

  def after_destroy(service)
    expire_cache_for(service)
  end

  private

  def expire_cache_for(service)
    # expire_action doesn't work with our custom routes, so instead use
    # expire_fragment with a regex. Not ideal, but seems to work.
    expire_fragment(/#{service.url_path}$/)
  end
end
