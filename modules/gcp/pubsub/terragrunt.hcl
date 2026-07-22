terraform {
  source = "tfr:///terraform-google-modules/pubsub/google?version=8.7.0"
}

# Default inputs — override from individual topic terragrunt.hcl
inputs = {
  push_subscriptions          = []
  pull_subscriptions          = []
  bigquery_subscriptions      = []
  cloud_storage_subscriptions = []
  topic_labels                = {}
  subscription_labels         = {}
}
