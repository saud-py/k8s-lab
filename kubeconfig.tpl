apiVersion: v1
kind: Config
clusters:
- name: "${cluster_name}"
  cluster:
    certificate-authority-data: ${cluster_ca_cert}
    server: ${cluster_endpoint}
contexts:
- name: "${cluster_name}"
  context:
    cluster: "${cluster_name}"
    user: aws
current-context: "${cluster_name}"
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args:
        - "eks"
        - "get-token"
        - "--region"
        - "${aws_region}"
        - "--cluster-name"
        - "${cluster_name}"