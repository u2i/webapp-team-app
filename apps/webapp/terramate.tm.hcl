# Webapp app configuration
globals {
  app_name    = "webapp"
  team        = "webapp"
  github_repo = "webapp-team-infrastructure"
  
  # Domain configuration
  prod_domain    = "u2i.com"
  nonprod_domain = "u2i.dev"
  
  # App-specific labels
  app_labels = {
    app         = global.app_name
    managed_by  = "terramate"
    team        = global.team
  }
}