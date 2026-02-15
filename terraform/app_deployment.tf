################################################################################
# 4.2 Application Deployment & 5.2 Advanced Networking (Ingress)
################################################################################

# Create Namespace
resource "kubernetes_namespace" "retail_app" {
  metadata {
    name = "retail-app"
  }
}

################################################################################
# AWS Load Balancer Controller (Prerequisite for Ingress)
################################################################################

module "lb_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name                              = "bedrock-lbs-role"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.lb_role.iam_role_arn
  }
}

################################################################################
# Retail Store Sample App Deployment
################################################################################

resource "helm_release" "retail_app" {
  name             = "retail-store-sample-app" 
  repository = "https://aws-containers.github.io/retail-store-sample-app"
  chart      = "retail-store-sample-app"
  namespace  = kubernetes_namespace.retail_app.metadata[0].name
  version    = "1.0.0" # approximate

  set {
    name  = "catalog.mysql.host"
    value = module.mysql_catalog.db_instance_address
  }
  
  set {
    name  = "orders.postgres.host"
    value = module.postgres_orders.db_instance_address
  }
  
  # Ensure Ingress is enabled
  set {
    name  = "ui.ingress.enabled"
    value = "true"
  }
  
  set {
    name  = "ui.ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }
  
  set {
    name  = "ui.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }
  
  set {
    name  = "ui.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  depends_on = [
    module.eks, 
    helm_release.aws_load_balancer_controller,
    module.mysql_catalog,
    module.postgres_orders
  ]
}

################################################################################
# Ingress Resource (Explicit - if not handled by Helm)
################################################################################
# Note: if the Helm chart creates ingress, this is redundant. 

resource "kubernetes_ingress_v1" "retail_ingress" {
  metadata {
    name      = "retail-store-ingress"
    namespace = kubernetes_namespace.retail_app.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"               = "alb"
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      # Magic DNS using nip.io will be handled after apply when we know the ALB DNS
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "ui" # Assumption: Service name is 'ui'
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
