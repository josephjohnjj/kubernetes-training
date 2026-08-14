#!/usr/bin/env bash
set -euo pipefail

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rendered_file="$(mktemp)"
trap 'rm -f "${rendered_file}"' EXIT

values=(
  --values "${chart_dir}/values/gen3-values.yaml"
  --values "${chart_dir}/values.d/00-etl-mapping.yaml"
  --values "${chart_dir}/values.d/01-usersync.yaml"
  --values "${chart_dir}/values.d/02-portal-gitops-css.yaml"
  --values "${chart_dir}/values.d/03-portal-gitops-json.yaml"
)

helm lint "${chart_dir}" "${values[@]}"
helm template gen3 "${chart_dir}" --namespace gen3 "${values[@]}" > "${rendered_file}"

ruby -ryaml -rjson -rbase64 -e '
  documents = YAML.load_stream(File.read(ARGV[0])).compact

  portal = documents.find do |document|
    document["kind"] == "Secret" && document.dig("metadata", "name") == "portal-config"
  end
  raise "portal-config was not rendered" unless portal
  JSON.parse(Base64.decode64(portal.dig("data", "gitops.json")))

  indexd = documents.find do |document|
    document["kind"] == "Secret" && document.dig("metadata", "name") == "indexd-settings"
  end
  settings = Base64.decode64(indexd.dig("data", "local_settings.py"))
  raise "Indexd settings do not use PGHOST" unless settings.include?("PGHOST")

  fence = documents.find do |document|
    document["kind"] == "Secret" && document.dig("metadata", "name") == "fence-config"
  end
  fence_config = YAML.safe_load(fence.dig("stringData", "fence-config.yaml"))
  idp = fence_config.dig("OPENID_CONNECT", "generic_oidc_idp")
  raise "Fence OIDC discovery_url must be disabled" unless idp["discovery_url"].nil?
  unless idp.dig("discovery", "authorization_endpoint") == "https://keycloak.44.203.188.20.nip.io/realms/genome/protocol/openid-connect/auth"
    raise "Fence OIDC browser authorization endpoint is incorrect"
  end
  %w[token_endpoint jwks_uri userinfo_endpoint].each do |endpoint|
    unless idp.dig("discovery", endpoint)&.start_with?("http://keycloak.keycloak.svc.cluster.local/")
      raise "Fence OIDC #{endpoint} does not use the internal Keycloak service"
    end
  end

  fence_deployment = documents.find do |document|
    document["kind"] == "Deployment" && document.dig("metadata", "name") == "fence-deployment"
  end
  fence_image = fence_deployment.dig("spec", "template", "spec", "containers", 0, "image")
  expected_fence_image = "quay.io/cdis/fence:master@sha256:5b00f1d4c5ad1087ad39313e132a6828e1c875e5e8bff405cef4b48b1392ad75"
  raise "Fence image is not pinned to the compatible digest" unless fence_image == expected_fence_image

  bootstrap = documents.find do |document|
    document["kind"] == "Job" && document.dig("metadata", "name") == "gen3-elasticsearch-bootstrap"
  end
  unless bootstrap&.dig("metadata", "annotations", "argocd.argoproj.io/hook") == "PreSync"
    raise "Elasticsearch PreSync bootstrap job was not rendered"
  end
' "${rendered_file}"

if grep -Eq 'image:.*quay.io/cdis/(arborist|audit-service|data-portal|fence|guppy|hatchery|indexd|manifestservice|metadata-service|nginx|peregrine|sheepdog|workspace-token-service|tube|gen3-spark):(master|main|latest)([[:space:]]|$)' "${rendered_file}"; then
  echo "A core Gen3 workload still uses a mutable image tag" >&2
  exit 1
fi

grep -q 'mountPath: /indexd/local_settings.py' "${rendered_file}"
grep -q 'mountPath: /indexd/deployment/wsgi/wsgi.py' "${rendered_file}"
grep -q 'application = get_app(settings)' "${rendered_file}"
grep -q 'name: ES_PASSWORD' "${rendered_file}"
grep -q 'mountPath: /fence/keys/key' "${rendered_file}"
grep -q 'name: fence-jwt-workdir' "${rendered_file}"

ruby -ryaml -e '
  documents = YAML.load_stream(File.read(ARGV[0])).compact
  secret = documents.find do |document|
    document["kind"] == "Secret" && document.dig("metadata", "name") == "indexd-settings"
  end
  encoded_settings = secret&.dig("data", "local_settings.py")
  raise "Indexd settings Secret is missing local_settings.py" if encoded_settings.nil? || encoded_settings.empty?

  cronjob = documents.find do |document|
    document["kind"] == "CronJob" && document.dig("metadata", "name") == "fence-delete-expired-clients"
  end
  env = cronjob.dig("spec", "jobTemplate", "spec", "template", "spec", "containers", 0, "env")
  names = env.map { |entry| entry["name"] }
  required = %w[DB FENCE_DB]
  missing = required - names
  raise "Fence cleanup job is missing: #{missing.join(", ")}" unless missing.empty?
' "${rendered_file}"

echo "Gen3 compatibility validation passed."
