module KubernetesHelpers
  include Gitlab::Kubernetes

  def kube_response(body)
    { body: body.to_json }
  end

  def kube_pods_response
    kube_response(kube_pods_body)
  end

  def stub_kubeclient_discover
    WebMock.stub_request(:get, service.api_url + '/api/v1').to_return(kube_response(kube_v1_discovery_body))
  end

  def stub_kubeclient_pods(response = nil)
    stub_kubeclient_discover
    pods_url = service.api_url + "/api/v1/namespaces/#{service.actual_namespace}/pods"

    WebMock.stub_request(:get, pods_url).to_return(response || kube_pods_response)
  end

  def kube_v1_discovery_body
    {
      "kind" => "APIResourceList",
      "resources" => [
        { "name" => "pods", "namespaced" => true, "kind" => "Pod" }
      ]
    }
  end

  def kube_pods_body
    {
      "kind" => "PodList",
      "items" => [kube_pod]
    }
  end

  # This is a partial response, it will have many more elements in reality but
  # these are the ones we care about at the moment
  def kube_pod(name: "kube-pod", app: "valid-pod-label")
    {
      "metadata" => {
        "name" => name,
        "creationTimestamp" => "2016-11-25T19:55:19Z",
        "labels" => { "app" => app }
      },
      "spec" => {
        "containers" => [
          { "name" => "container-0" },
          { "name" => "container-1" }
        ]
      },
      "status" => { "phase" => "Running" }
    }
  end

  def kube_terminals(service, pod)
    pod_name = pod['metadata']['name']
    containers = pod['spec']['containers']

    containers.map do |container|
      terminal = {
        selectors: { pod: pod_name, container: container['name'] },
        url:  container_exec_url(service.api_url, service.actual_namespace, pod_name, container['name']),
        subprotocols: ['channel.k8s.io'],
        headers: { 'Authorization' => ["Bearer #{service.token}"] },
        created_at: DateTime.parse(pod['metadata']['creationTimestamp']),
        max_session_time: 0
      }
      terminal[:ca_pem] = service.ca_pem if service.ca_pem.present?
      terminal
    end
  end
end
