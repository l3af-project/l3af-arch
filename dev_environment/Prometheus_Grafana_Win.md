## Installing Grafana and Prometheus on Windows System

### Installation of Grafana on Window

Navigate to https://grafana.com/grafana/download?platform=windows and Download Grafana for windows (https://dl.grafana.com/enterprise/release/grafana-enterprise-9.0.3.windows-amd64.msi)

After installation check `Grafana Service` is running

![Grafana_svc](../images/l3af-on-windows/prometheus_grafana/Grafana_svc.png)

Navigate to http://localhost:3000/login

> Note: The default username and password is `admin`.

![Grafana_Dashboard1](../images/l3af-on-windows/prometheus_grafana/Grafana_Dashboard1.png)

![Grafana_Dashboard2](../images/l3af-on-windows/prometheus_grafana/Grafana_Dashboard2.png)

### Installation of Prometheus as Service in Windows

You can download Prometheus for windows from https://prometheus.io/download/. However, installing prometheus as a service you need to use `NSSM explorer`.

So, if you have installed Grafana first then `NSSM explorer` must be downloaded as part of Grafana. You can go to the path where Grafana is installed and can find a folder named as “**svc-9.0.3.0**”. Under this folder you can find `nssm.exe`.

If you have not installed Grafana in your system then you can install Prometheus by downloading `nssm.exe`. You can download from https://nssm.cc/download.

- Navigate the `NSSM.exe` path through command prompt
- Run Below Command:

```bash
nssm.exe install prometheus <The path where prometheus application downloaded>
```

For example:
![Prometheus_Install](../images/l3af-on-windows/prometheus_grafana/Prometheus_Install.png)

Open `service.msc` and you can see prometheus service is installed

![service_msc](../images/l3af-on-windows/prometheus_grafana/service_msc.png)

Before starting the prometheus service, install **WMI Exporter**:

For installing WMI Exporter, you need to download `wmi exporter` from https://github.com/prometheus-community/windows_exporter/releases/download/v0.18.1/windows_exporter-0.18.1-amd64.msi

Post installation of `wmi exporter`, you can validate by navigating to http://localhost:9182/

![Win_exporter](../images/l3af-on-windows/prometheus_grafana/Win_exporter.png)

Click on Metrics link

![metrices](../images/l3af-on-windows/prometheus_grafana/metrices.png)

You can also validate `windows_exporter` service is running:

![WMI_exporter_svc](../images/l3af-on-windows/prometheus_grafana/WMI_exporter_svc.png)

Navigate to prometheus `config file path` and open the “**prometheus.yml**”

You need to add job for `wmi exporter` and `l3afd` , as shown below:

![prometheus_yaml](../images/l3af-on-windows/prometheus_grafana/prometheus_yaml.png)

Now run Run Prometheus service

![prometheus_svc](../images/l3af-on-windows/prometheus_grafana/prometheus_svc.png)

After starting Prometheus service, navigate to http://localhost:9090/

![prometheus_dashboard](../images/l3af-on-windows/prometheus_grafana/prometheus_dashboard.png)

Now you can access Prometheus service.

You can also see `l3afd metric` graph using prometheus:

![prometheus_graph](../images/l3af-on-windows/prometheus_grafana/prometheus_graph.png)

## Grafana Dashboard files by l3af:
- [Check Here](../dev_environment/cfg/grafana/dashboards/)

You can use these `json` files to create dashboard for monitoring of `eBPF programs` in `Grafana`

![grafana_json](../images/l3af-on-windows/prometheus_grafana/grafana_json.png)

#### eBPF program monitoring:
![eBPF_program](../images/l3af-on-windows/prometheus_grafana/eBPF_program.png)