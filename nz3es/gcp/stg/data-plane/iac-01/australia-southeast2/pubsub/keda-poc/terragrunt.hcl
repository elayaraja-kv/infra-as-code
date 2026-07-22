# KEDA autoscaling POC fixture — a topic + pull subscription whose backlog
# (num_undelivered_messages) drives the "queue_backlog" trigger in
# k8s-as-code apps/keda-poc. See k8s-as-code CLAUDE.md / plan for the full
# composite-scaling design (backlog scales up, Cloud SQL CPU throttles down).

include "root" {
  path   = find_in_parent_folders("root-gcp.hcl")
  expose = true
}

include "pubsub" {
  path = "${get_repo_root()}/modules/gcp/pubsub/terragrunt.hcl"
}

inputs = {
  project_id = include.root.locals.project_id
  topic      = "keda-poc-topic"

  # Pull-only, no push endpoint — undelivered test messages accumulate as
  # backlog for the ScaledObject to read via Cloud Monitoring.
  pull_subscriptions = [
    {
      name                         = "keda-poc-sub"
      ack_deadline_seconds         = 60
      message_retention_duration   = "86400s" # 24h — plenty of headroom for manual test runs
      expiration_policy            = null
      dead_letter_topic            = null
      max_delivery_attempts        = null
      retain_acked_messages        = false
      maximum_backoff              = null
      minimum_backoff              = null
      filter                       = null
      enable_message_ordering      = false
      service_account              = null
      enable_exactly_once_delivery = false
    }
  ]

  topic_labels = include.root.locals.labels
}
