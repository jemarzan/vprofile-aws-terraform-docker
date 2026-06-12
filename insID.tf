# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "instance_id" {
  description = "EC2 Instance ID of the vprofile Docker host"
  value       = aws_instance.vprofile_docker.id
}

output "instance_public_ip" {
  description = "Elastic IP (stable public IP) of the vprofile Docker host"
  value       = aws_eip.vprofile.public_ip
}

output "instance_private_ip" {
  description = "Private IP of the vprofile Docker host"
  value       = aws_instance.vprofile_docker.private_ip
}

output "instance_type" {
  description = "EC2 instance type used"
  value       = aws_instance.vprofile_docker.instance_type
}

output "key_pair_name" {
  description = "Name of the EC2 key pair"
  value       = aws_key_pair.vprofile.key_name
}

output "pem_file_path" {
  description = "Path to the generated private key .pem file (use this to SSH in)"
  value       = local_sensitive_file.private_key_pem.filename
}

output "security_group_id" {
  description = "Security group ID attached to the Docker host"
  value       = aws_security_group.vprofile_docker.id
}

output "ssh_command" {
  description = "Ready-to-use SSH command"
  value       = "ssh -i ${var.project_name}-${var.environment}.pem ubuntu@${aws_eip.vprofile.public_ip}"
}

output "vprofile_url" {
  description = "vprofile web application URL"
  value       = "http://${aws_eip.vprofile.public_ip}"
}

output "vproapp_direct_url" {
  description = "Tomcat direct URL (bypasses Nginx)"
  value       = "http://${aws_eip.vprofile.public_ip}:8080"
}
