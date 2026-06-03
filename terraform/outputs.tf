output "container_name" {
  description = "Nom du conteneur déployé"
  value       = docker_container.stacknova_recette.name
}

output "exposed_port" {
  description = "Port exposé sur l'hôte"
  value       = docker_container.stacknova_recette.ports[0].external
}
