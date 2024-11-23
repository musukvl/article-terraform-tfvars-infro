resource "random_pet" "server" {
  length = var.pet_name_length
}

output "pet_name" {
  value = random_pet.server.id
}
