.PHONY: all
all: generate

.PHONY: generate
generate: deps prometheusrules servicemonitors grafana slos manifests

.PHONY: prometheusrules
prometheusrules: resources/observability/prometheusrules

resources/observability/prometheusrules: prometheusrules.jsonnet
	rm -f resources/observability/prometheusrules/observatorium-thanos-production.prometheusrules.yaml
	rm -f resources/observability/prometheusrules/observatorium-thanos-stage.prometheusrules.yaml
	jsonnetfmt -i prometheusrules.jsonnet
	jsonnet -J vendor -m resources/observability/prometheusrules prometheusrules.jsonnet | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml' -- {}
	find resources/observability/prometheusrules -type f ! -name '*.yaml' -delete
	find resources/observability/prometheusrules/*.yaml | xargs -I {} sh -c '/bin/echo -e "---\n\$$schema: /openshift/prometheus-rule-1.yml\n$$(cat {})" > {}'

.PHONY: servicemonitors
servicemonitors: resources/observability/servicemonitors

resources/observability/servicemonitors: servicemonitors.jsonnet
	rm -f resources/observability/servicemonitors/*.yaml
	jsonnetfmt -i servicemonitors.jsonnet
	jsonnet -J vendor -m resources/observability/servicemonitors servicemonitors.jsonnet | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml' -- {}
	find resources/observability/servicemonitors -type f ! -name '*.yaml' -delete

.PHONY: grafana
grafana: resources/observability/grafana

resources/observability/grafana: grafana.jsonnet
	rm -f resources/observability/grafana/*.yaml
	jsonnetfmt -i grafana.jsonnet
	jsonnet -J vendor -m resources/observability/grafana grafana.jsonnet | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml' -- {}
	find resources/observability/grafana -type f ! -name '*.yaml' -delete

.PHONY: slos
slos: resources/observability/slo/telemeter.slo.yaml

resources/observability/slo/telemeter.slo.yaml: slo.jsonnet
	jsonnetfmt -i slo.jsonnet
	jsonnet -J vendor slo.jsonnet | gojsontoyaml > resources/observability/slo/telemeter.slo.yaml
	find resources/observability/slo/*.yaml | xargs -I {} sh -c '/bin/echo -e "---\n\$$schema: /openshift/prometheus-rule-1.yml\n$$(cat {})" > {}'

.PHONY: manifests
manifests:
	# Make sure to start with a clean 'manifests' dir
	rm -rf manifests/production/*
	mkdir -p manifests/production
	jsonnetfmt -i environments/production/main.jsonnet
	jsonnetfmt -i environments/production/jaeger.jsonnet
	jsonnet -J vendor environments/production/main.jsonnet | gojsontoyaml >manifests/production/observatorium-template.yaml
	jsonnet -J vendor environments/production/jaeger.jsonnet | gojsontoyaml >manifests/production/jaeger-template.yaml
	find manifests/production -type f ! -name '*.yaml' -delete


.PHONY: deps
deps:
	@jb install