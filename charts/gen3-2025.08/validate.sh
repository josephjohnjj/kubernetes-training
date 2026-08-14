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

  bootstrap = documents.find do |document|
    document["kind"] == "Job" && document.dig("metadata", "name") == "gen3-elasticsearch-bootstrap"
  end
  unless bootstrap&.dig("metadata", "annotations", "argocd.argoproj.io/hook") == "PreSync"
    raise "Elasticsearch PreSync bootstrap job was not rendered"
  end
' "${rendered_file}"

if grep -Eq 'image:.*quay.io/cdis/(arborist|audit-service|data-portal|fence|guppy|hatchery|indexd|manifestservice|metadata-service|nginx|peregrine|sheepdog|workspace-token-service|tube|gen3-spark):(master|main|latest)' "${rendered_file}"; then
  echo "A core Gen3 workload still uses a mutable image tag" >&2
  exit 1
fi

grep -q 'mountPath: /indexd/local_settings.py' "${rendered_file}"
grep -q 'mountPath: /indexd/deployment/wsgi/wsgi.py' "${rendered_file}"
grep -q 'application = get_app(settings)' "${rendered_file}"
grep -q 'name: ES_PASSWORD' "${rendered_file}"

ruby -ryaml -e '
  documents = YAML.load_stream(File.read(ARGV[0])).compact
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
