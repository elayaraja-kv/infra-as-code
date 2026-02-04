include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../../../../modules/vpc"
}

inputs = {
  project_id = include.root.locals.project_id
  name       = format("%s-%s", include.root.locals.environment, include.root.locals.project)

  subnets = {
    "ause2" = {
      region = "australia-southeast2"
      cidr   = "10.1.0.0/24"
      secondary_ip_ranges = [
        { range_name = "gke-pods", ip_cidr_range = "10.100.0.0/16" },
        { range_name = "gke-services", ip_cidr_range = "10.200.0.0/20" },
      ]
    },
    "ause1" = {
      region = "australia-southeast1"
      cidr   = "10.2.0.0/24"
    }
  }
}
