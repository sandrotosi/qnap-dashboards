# QNAP Dashboards

This repo contains information on how to setup

* [Prometheus](https://prometheus.io/)
* [Grafana](https://grafana.com/grafana/)
* other relevant tools

on your QNAP NAS to collect data and a graphical visualization of it.

(I'm not sure it's relevant, but my system is a TVS-473 running 4.4.1.1146 firmware, so things may vary slighyl if you're in a different configuration.)

## Software installation

There are probably several methods you can use to install the required tools, but the one i find most effective is to use [Qnapclub](https://www.qnapclub.eu/en) packages; just follow [their tutorial](https://www.qnapclub.eu/en/howto/1) on how to get started.

Once that's done, go ahead and install:

* [Grafana](https://www.qnapclub.eu/en/qpkg/812), the graphical dashboard that will show your data
* [Prometheus](https://www.qnapclub.eu/en/qpkg/779), the data collector/aggregator
* [Prometheus node-exporter](https://www.qnapclub.eu/en/qpkg/778), the program that collects NAS system information

### First steps after installation

The init scripts for the tools just installed are in `/etc/init.d` specifically:

* `/etc/init.d/Grafana.sh {start|stop|restart}`
* `/etc/init.d/Prometheus.sh {start|stop|restart}`
* `/etc/init.d/NodeExporter.sh {start|stop|restart}`

#### Prometheus

Prometheus main program collects data from all the configured exporters, which retrieve and _expose_ them for Prometheus consumption (usually via an HTTP endpoint); so now we need to tell Prometheus to collect data from `node_exporter`.

Prometheus config file is at `/share/CACHEDEV1_DATA/.qpkg/Prometheus/prometheus.yml`, we're gonna have to add lines like:

```
scrape_configs:
  .....

  - job_name: 'node'
    static_configs:
    - targets: ['localhost:9100']

```

at the bottom of the file (or anywhere the `strace_configs` section is) and restart Prometheus. Make sure the new source is configured by looking at <http://nas_address:9090/targets> and making sure the new `node` endpoint is up and scraped recently.

By default, Prometheus keeps 15 days of data, you may want to increase that. Prometheus [configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/) is done via both command-line switches and a configuration file.

For [storage](https://prometheus.io/docs/prometheus/latest/storage/) options, we need to use the command-line switches: edit `/etc/init.d/Prometheus.sh` to replace:

```
$QPKG_ROOT/prometheus &
```

with

```
$QPKG_ROOT/prometheus --storage.tsdb.retention.time=TIME &
```

for my configuration i chose `TIME` to be `1095d` (3 years); restart Prometheus and make sure the configuration has been accepted correctly by browsing to <http://nas_address:9090/flags> and check the `storage.tsdb.retention.time` flag.

**WARNING** the init file (which is actually a symlink to `/share/CACHEDEV1_DATA/.qpkg/Prometheus/Prometheus.sh`) will get changed (and reverted to its original content) on upgrade.

#### Grafana

We now have Prometheus collecting data, it's time to visualize it: Grafana will fulfill this duty.

Just go to <http://nas_address:3000/> (default login is admin/admin; change the password as suggested): a new installation menu will guide you to the setup procedure, which starts with the configuration of the first datasource, which will be the Prometheus instance we just configured.

Grafana doesnt come with any dashboard out of the box, but there's an active community on their [website](https://grafana.com/grafana/dashboards) from where you can import dashboards designed by others; a very good initial OS status dashboard can be found [here](https://grafana.com/grafana/dashboards/6287) which uses the data exported by `node_exporter` to populate the widgets.

