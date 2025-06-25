terramate {
  required_version = ">= 0.10.0"
  
  config {
    git {
      check_untracked   = false
      check_uncommitted = false
      check_remote      = false
    }
  }
}

globals {
  # Organization-wide globals
  org_id          = "981978971260"
  org_domain      = "u2i.com"
  billing_account = "017E25-21F01C-DF5C27"
  
  # Shared state configuration
  shared_state_bucket = "u2i-tfstate"
  shared_state_prefix = "terramate"
  
  # Default regions
  primary_region   = "europe-west1"
  secondary_region = "europe-west3"
  
  # GitHub organization
  github_org = "u2i"
  
  # Default labels
  default_labels = {
    managed_by  = "terramate"
  }
  
  # Compliance frameworks
  compliance_frameworks = ["iso27001", "soc2", "gdpr"]
}

# Stack defaults
stack {
  after = [
    "tag:foundation",
  ]
}