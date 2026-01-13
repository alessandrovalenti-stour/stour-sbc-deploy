output "vip_public_ip" {
  value = aws_eip.vip.public_ip
}

output "vip_allocation_id" {
  value = aws_eip.vip.allocation_id
}

output "sbc_a_public_ip" {
  value = aws_instance.sbc_a.public_ip
}

output "sbc_b_public_ip" {
  value = aws_instance.sbc_b.public_ip
}

output "sbc_a_private_ip" {
  value = aws_instance.sbc_a.private_ip
}

output "sbc_b_private_ip" {
  value = aws_instance.sbc_b.private_ip
}

output "ansible_inventory_path" {
  value = local_file.ansible_inventory.filename
}

