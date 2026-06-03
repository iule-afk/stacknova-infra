resource "docker_image" "nginx" {
  name         = "nginx:1.25.3"
  keep_locally = true
}
resource "docker_container" "stacknova_recette" {
  name  = "stacknova-recette"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8080
  }

  labels {
    label = "env"
    value = "recette"
  }

  labels {
    label = "project"
    value = "stacknova"
  }
}
