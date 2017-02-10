variable "env" { default = "production" }
variable "gce_bastion_image" { default = "eco-emissary-99515/bastion-1478778272" }
variable "gce_gcloud_zone" {}
variable "gce_heroku_org" {}
variable "gce_worker_image" { default = "eco-emissary-99515/travis-worker-1480649763" }
variable "github_users" {}
variable "job_board_url" {}
variable "travisci_net_external_zone_id" { default = "Z2RI61YP4UWSIO" }
variable "syslog_address_com" {}
variable "syslog_address_org" {}

provider "google" { project = "travis-ci-prod-7" }
provider "aws" {}
provider "heroku" {}

module "gce_project_7" {
  source = "../modules/gce_project"
  bastion_config = "${file("${path.module}/config/bastion-env")}"
  bastion_image = "${var.gce_bastion_image}"
  env = "${var.env}"
  gcloud_cleanup_account_json = "${file("${path.module}/config/gce-cleanup-production-7.json")}"
  gcloud_cleanup_job_board_url = "${var.job_board_url}"
  gcloud_zone = "${var.gce_gcloud_zone}"
  github_users = "${var.github_users}"
  heroku_org = "${var.gce_heroku_org}"
  index = "7"
  project = "travis-ci-prod-7"
  syslog_address_com = "${var.syslog_address_com}"
  syslog_address_org = "${var.syslog_address_org}"
  travisci_net_external_zone_id = "${var.travisci_net_external_zone_id}"
  worker_account_json_com = "${file("${path.module}/config/gce-workers-production-7.json")}"
  worker_account_json_org = "${file("${path.module}/config/gce-workers-production-7.json")}"
  worker_config_com = "${file("${path.module}/config/worker-env-com")}"
  worker_config_org = "${file("${path.module}/config/worker-env-org")}"
  worker_docker_self_image = "travisci/worker:v2.7.0"
  worker_image = "${var.gce_worker_image}"
  worker_instance_count_com = 10
  worker_instance_count_org = 0
}
