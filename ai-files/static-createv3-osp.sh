export AI_URL='http://10.17.3.1:8090'
export NIC_CONFIG='bond-static-osp'
export BASE_DNS_DOMAIN='lab.local'
export CLUSTER_NAME="ocpd"
export MACHINE_CIDR="10.17.3.0/24"
export VERSION="4.15"

#####Create cluster#####

jq -n  --arg PULLSECRET "$(cat pull-secret.json)" --arg SSH_KEY "$(cat ~/.ssh/id_ed25519.pub)" --arg VERSION "$VERSION" --arg DOMAIN "$BASE_DNS_DOMAIN" --arg CLUSTERN "$CLUSTER_NAME" --arg CIDR "$MACHINE_CIDR" '{
    "name": $CLUSTERN,
    "openshift_version": $VERSION,
    "base_dns_domain": $DOMAIN,
    "hyperthreading": "all",
    "olm_operators": [
      {
        "name": "lso",
      },
      {
        "name": "mce",
      },
      {
        "name": "odf",
      }
    ],
    "api_vips": [
    {
      "ip": "10.17.3.2",
      "verification": "unverified"
    }
    ],
    "ingress_vips": [
    {
      "ip": "10.17.3.3",
      "verification": "unverified"
    }
    ],
    "schedulable_masters": true,
    "platform": {
      "type": "baremetal"
     },
    "user_managed_networking": false,
    "cluster_networks": [
      {
        "cidr": "172.20.0.0/16",
        "host_prefix": 23
      }
    ],
    "service_networks": [
      {
        "cidr": "172.31.0.0/16"
      }
    ],
    "machine_networks": [
      {
        "cidr": $CIDR
      }
    ],
    "network_type": "OVNKubernetes",
    "additional_ntp_source": "ntp1.hetzner.de",
    "vip_dhcp_allocation": false,
    "high_availability_mode": "Full",
    # "hosts": [], 
    "ssh_public_key": $SSH_KEY,
    "pull_secret": $PULLSECRET
}' > deployment.json

curl -s -X POST "$AI_URL/api/assisted-install/v2/clusters" \
  -d @./deployment.json \
  --header "Content-Type: application/json" \
  | jq .

export CLUSTER_ID=$(curl -s -X GET "$AI_URL/api/assisted-install/v2/clusters?with_hosts=true" -H "accept: application/json" -H "get_unregistered_clusters: false"| jq -r '.[].id')
echo $CLUSTER_ID
rm -f deployment.json
#### add metallb operator manifest ####
# curl -X 'POST' \
#   "$AI_URL/api/assisted-install/v2/clusters/$CLUSTER_ID/manifests" \
#   -H 'accept: application/json' \
#   -H 'Content-Type: application/json' \
#   -d '{
#   "folder": "manifests",
#   "file_name": "metallb-operator.yaml",
#   "content":"LS0tCmFwaVZlcnNpb246IHYxCmtpbmQ6IE5hbWVzcGFjZQptZXRhZGF0YToKICBuYW1lOiBtZXRhbGxiLXN5c3RlbQotLS0KYXBpVmVyc2lvbjogb3BlcmF0b3JzLmNvcmVvcy5jb20vdjEKa2luZDogT3BlcmF0b3JHcm91cAptZXRhZGF0YToKICBuYW1lOiBtZXRhbGxiLW9wZXJhdG9yCiAgbmFtZXNwYWNlOiBtZXRhbGxiLXN5c3RlbQotLS0KYXBpVmVyc2lvbjogb3BlcmF0b3JzLmNvcmVvcy5jb20vdjFhbHBoYTEKa2luZDogU3Vic2NyaXB0aW9uCm1ldGFkYXRhOgogIG5hbWU6IG1ldGFsbGItb3BlcmF0b3Itc3ViCiAgbmFtZXNwYWNlOiBtZXRhbGxiLXN5c3RlbQpzcGVjOgogIGNoYW5uZWw6IHN0YWJsZQogIG5hbWU6IG1ldGFsbGItb3BlcmF0b3IKICBzb3VyY2U6IHJlZGhhdC1vcGVyYXRvcnMgMQogIHNvdXJjZU5hbWVzcGFjZTogb3BlbnNoaWZ0LW1hcmtldHBsYWNlCi0tLQphcGlWZXJzaW9uOiBtZXRhbGxiLmlvL3YxYmV0YTEKa2luZDogTWV0YWxMQgptZXRhZGF0YToKICBuYW1lOiBtZXRhbGxiCiAgbmFtZXNwYWNlOiBtZXRhbGxiLXN5c3RlbQ=="
# }'

######prepare infra####

jq -n --arg CLUSTERID "$CLUSTER_ID" --arg PULLSECRET "$(cat pull-secret.json)" \
      --arg SSH_KEY "$(cat ~/.ssh/id_ed25519.pub)" \
      --arg VERSION "$VERSION" \
      --arg NMSTATEM_YAML0 "$(cat ./$NIC_CONFIG/nmstate-$NIC_CONFIG-master0.yaml)" --arg NMSTATEM_YAML1 "$(cat ./$NIC_CONFIG/nmstate-$NIC_CONFIG-master1.yaml)" --arg NMSTATEM_YAML2 "$(cat ./$NIC_CONFIG/nmstate-$NIC_CONFIG-master2.yaml)" \
      --arg NMSTATE_YAML0 "$(cat ./$NIC_CONFIG/nmstate-$NIC_CONFIG-worker0.yaml)" --arg NMSTATE_YAML1 "$(cat ./$NIC_CONFIG/nmstate-$NIC_CONFIG-worker1.yaml)" --arg NMSTATE_YAML2 "$(cat ./$NIC_CONFIG/nmstate-$NIC_CONFIG-worker2.yaml)" '{
  "name": "ocpd_infra-env",
  "openshift_version": $VERSION,
  "pull_secret": $PULLSECRET,
  "ssh_authorized_key": $SSH_KEY,
  "image_type": "full-iso",
  "cluster_id": $CLUSTERID,
  "additional_trust_bundle": "-----BEGIN CERTIFICATE-----\nMIID5TCCAs2gAwIBAgIUWh+B6q0QEcvNf8P2lbp2Z0ymQEYwDQYJKoZIhvcNAQEL\nBQAwbzELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAlZBMREwDwYDVQQHDAhOZXcgWW9y\nazENMAsGA1UECgwEUXVheTERMA8GA1UECwwIRGl2aXNpb24xHjAcBgNVBAMMFW9z\ncC1oZXR6bmVyLmxhYi5sb2NhbDAeFw0yNDA1MjExNTI4MTVaFw0yNzAzMTExNTI4\nMTVaMG8xCzAJBgNVBAYTAlVTMQswCQYDVQQIDAJWQTERMA8GA1UEBwwITmV3IFlv\ncmsxDTALBgNVBAoMBFF1YXkxETAPBgNVBAsMCERpdmlzaW9uMR4wHAYDVQQDDBVv\nc3AtaGV0em5lci5sYWIubG9jYWwwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK\nAoIBAQDiFN2e66Ki7dOckN//WFr9OnL8PLjxKYdf4LekaxtP7im8OnfQ0Gbs5tmS\nf0MpX99fvf7zBAmr+scHRMyoPWmZAwr8WlpHRnVSzfsGrhLuDIQNexA78COm6rpH\nwy/Md8DjWwaywpYTxEdgZG2/AimdS+WlUzzf+mwfz4QtR/ojdzual9Vywu4xIGZz\nm5bCazayJLb7GhWsJN3bFFXs2Lt6ZJpzjOtcH4aq5wobviFP2zS7mhOgS+uyyMaV\nVtG52oRv9WsTQL3hl4X1F75oj16bHJW9N/Qkb5CHijGiRig8hrN6cltaVg2i6ZJJ\nkYzWjT2y13k7hFebQ4AOG8v/o205AgMBAAGjeTB3MAsGA1UdDwQEAwIC5DATBgNV\nHSUEDDAKBggrBgEFBQcDATAgBgNVHREEGTAXghVvc3AtaGV0em5lci5sYWIubG9j\nYWwwEgYDVR0TAQH/BAgwBgEB/wIBATAdBgNVHQ4EFgQUlL109uv4DHJwqOAlXp3h\nQV5tqigwDQYJKoZIhvcNAQELBQADggEBANpB9fb0kLdohvxXU9hhsJQkLd47IWel\nUP4sAVZXjAW6Vn2WM03+yYqlM5y0hDd0dEkanHk/Q/KvP4A5MuwNks6Iyj+IDmw2\nA2+h6y6uHoGE4LqHrVeATcNBSlwYP1FbIPcCFZHuih+YE3iOFM/ROuwF8iMZXX12\n5cEhd+l1GwsamLYVIY6ejwGmH6CfhMeNM/mnJfslEJGNGBb9Gd+ws6rRE9GZSdaP\nqm4TI6i9yCvavChNZUAGyW27V017LczVyUUdSTpo7r8TPW3XcwZlGyVJ1yL0dzaP\nfvAVBoM5K96symKImMdg9/hK1WjfAoJE+aZT06CPZnSRhpuS73HiuYY=\n-----END CERTIFICATE-----",
  "static_network_config": [
    {
      "network_yaml": $NMSTATE_YAML0,
      "mac_interface_map": [{"mac_address": "aa:bb:cc:11:42:20", "logical_nic_name": "ens3"}, {"mac_address": "aa:bb:cc:11:42:50", "logical_nic_name": "ens4"},{"mac_address": "aa:bb:cc:11:42:60", "logical_nic_name": "ens5"}]
    },
    {
      "network_yaml": $NMSTATE_YAML1,
      "mac_interface_map": [{"mac_address": "aa:bb:cc:11:42:21", "logical_nic_name": "ens3"}, {"mac_address": "aa:bb:cc:11:42:51", "logical_nic_name": "ens4"},{"mac_address": "aa:bb:cc:11:42:61", "logical_nic_name": "ens5"}]
    },
    {
      "network_yaml": $NMSTATE_YAML2,
      "mac_interface_map": [{"mac_address": "aa:bb:cc:11:42:22", "logical_nic_name": "ens3"}, {"mac_address": "aa:bb:cc:11:42:52", "logical_nic_name": "ens4"},{"mac_address": "aa:bb:cc:11:42:62", "logical_nic_name": "ens5"}]
    }
  ]
}' > nmstate-$NIC_CONFIG

curl -H "Content-Type: application/json" -X POST -d @nmstate-$NIC_CONFIG ${AI_URL}/api/assisted-install/v2/infra-envs | jq .

export INFRAENV_ID=$(curl -X GET "$AI_URL/api/assisted-install/v2/infra-envs" -H "accept: application/json" | jq -r '.[].id' | awk 'NR<2')
echo $INFRAENV_ID

rm -rf nmstate-$NIC_CONFIG


ISO_URL=$(curl -X GET "$AI_URL/api/assisted-install/v2/infra-envs/$INFRAENV_ID/downloads/image-url" -H "accept: application/json"|jq -r .url)
rm -rf /var/lib/libvirt/images/discovery_image.iso
curl -X GET "$ISO_URL" -H "accept: application/octet-stream" -o /var/lib/libvirt/images/discovery_image.iso

terraform  -chdir=../terraform/ocp4-lab-3nodes apply -auto-approve


rm -rf ~/.kube
mkdir ~/.kube
curl -X GET $AI_URL/api/assisted-install/v2/clusters/$CLUSTER_ID/downloads/credentials?file_name=kubeconfig \
     -H 'accept: application/octet-stream' > /root/.kube/config

#####Get console passwords######

curl -X 'GET' \
  "$AI_URL/api/assisted-install/v2/clusters/$CLUSTER_ID/downloads/credentials?file_name=kubeadmin-password" \
  -H 'accept: application/octet-stream' \
  -w "\n"


curl -X 'GET' "$AI_URL/api/assisted-install/v2/infra-envs/9dd8d69d-38cb-4825-9513-6efd8c7e3390/hosts" -H 'accept: application/json'
