data "external" "env" {
  program = ["${path.module}/env.sh"]
}

data "google_compute_default_service_account" "default" {
}

resource "google_compute_network" "vpc_network" {
  project                 = data.external.env.result["project"]
  name                    = "node-app-vpc-network"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "subnetwork_1" {
  name          = "node-app-vpc-sub-network-1"
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_subnetwork" "subnetwork_2" {
  name          = "node-app-vpc-sub-network-2"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_instance_template" "inst_template_public" {
  name_prefix = "node-app-inst-template-public"
  labels = {
    app-name         = "node-app"
    server-visiblity = "public"
  }

  tags = ["node-app-server-public"]

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2204-jammy-v20230606"
    auto_delete  = true
    boot         = true
  }
  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnetwork_1.id
    # access_config block makes the instance public. Uncomment this to make the instance public.
    access_config {
      network_tier = "STANDARD"
    }
  }

  metadata_startup_script = file("./vm-startup-script.sh")

  machine_type = "e2-medium"

  lifecycle {
    create_before_destroy = true
  }

  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_region_instance_group_manager" "mig_public" {
  name               = "node-app-managed-instance-group-public"
  base_instance_name = "node-app-server-public"


  version {
    instance_template = google_compute_instance_template.inst_template_public.self_link_unique
  }
  target_size = 1

  named_port {
    name = "node-app-port"
    port = 8080
  }

}

resource "google_compute_firewall" "ssh_from_iap_range" {
  name    = "allow-ingress-from-iap"
  network = google_compute_network.vpc_network.id
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
}

resource "google_compute_backend_service" "backend_service_public" {
  name                  = "node-app-load-balancer-backend-public"
  protocol              = "HTTP"
  port_name             = "node-app-port"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 10
  enable_cdn            = false
  health_checks         = [google_compute_health_check.health_check_public.id]
  backend {
    group           = google_compute_region_instance_group_manager.mig_public.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_health_check" "health_check_public" {
  name = "node-app-load-balancer-hc-public"
  # request_path        = "/"
  # port                = "8080"
  check_interval_sec  = 1
  timeout_sec         = 1
  unhealthy_threshold = 2
  healthy_threshold   = 2
  http_health_check {
    port         = "8080"
    request_path = "/"
  }
}

resource "google_compute_target_http_proxy" "target_http_proxy_public" {
  name    = "node-app-load-balancer-proxy-public"
  url_map = google_compute_url_map.compute_url_map_public.id
}


resource "google_compute_url_map" "compute_url_map_public" {
  name            = "node-app-load-balancer-public"
  default_service = google_compute_backend_service.backend_service_public.id
}

resource "google_compute_global_forwarding_rule" "forwarding_rule_public" {
  name                  = "node-app-load-balancer-front-end-public"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.target_http_proxy_public.id
}

module "agent_policy" {
  source     = "terraform-google-modules/cloud-operations/google//modules/agent-policy"
  version    = "~> 0.2.3"

  project_id = "mcmp-integration-qa"
  policy_id  = "ops-agents-example-policy"
  agent_rules = [
    {
      type               = "ops-agent"
      version            = "current-major"
      package_state      = "installed"
      enable_autoupgrade = true
    },
  ]
  group_labels = [
    {
      env = "prod"
      app = "myproduct"
    }
  ]
  os_types = [
    {
      short_name = "ubuntu"
      # version    = "8"
    },
  ]
}

output "env" {
  value = data.external.env.result
}