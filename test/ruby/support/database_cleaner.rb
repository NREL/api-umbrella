DatabaseCleaner.strategy = :truncation, {
  :except => [
    "config_versions",
    "admin_permissions",
    "api_users",
  ],
}
