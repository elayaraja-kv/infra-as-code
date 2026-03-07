output "instance_name" {
  value     = module.compute_instance.instances_details[0].name
  sensitive = true
}

output "internal_ip" {
  value     = module.compute_instance.instances_details[0].network_interface[0].network_ip
  sensitive = true
}

output "instance_template_self_link" {
  value = module.instance_template.self_link
}
