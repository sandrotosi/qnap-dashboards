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

We now have Prometheus collecting data, it's time to visualize it: [Grafana](https://prometheus.io/docs/visualization/grafana/) will fulfill this duty.

Just go to <http://nas_address:3000/> (default login is admin/admin; change the password as suggested): a new installation menu will guide you to the setup procedure, which starts with the configuration of the first datasource, which will be the Prometheus instance we just configured.

Grafana doesnt come with any dashboard out of the box, but there's an active community on their [website](https://grafana.com/grafana/dashboards) from where you can import dashboards designed by others; a very good initial OS status dashboard can be found [here](https://grafana.com/grafana/dashboards/6287) which uses the data exported by `node_exporter` to populate the widgets.

## Install and Configure the SNMP exporter

1. Enable SNMP on the nas: Control Panel > Network & File Services > SNMP
    1. enable SNMP
    1. Choose SNMP v1/v2 (`snmp_exporter` default)
    1. set Community string to `public` (`snmp_exporter` default)
    1. Apply

1. download the NAS MIB at the bottom of the same page as above (a copy of that file is available [here](NAS.mib), but prefer to redownload it)

1. now we need to generate the correct QNAP configuration (probably easier on a separate linux box, not the nas):
    1. follow [this doc](https://github.com/prometheus/snmp_exporter/tree/master/generator#building) to build the `generator`
    1. `$ cp /path/to/NAS.mib mibs/`
    1. replace the `generator.yml` content with (from [here](https://grafana.com/grafana/dashboards/9330)):
        ```
        modules:
          qnap:
            walk:
              - cpuUsage
              - systemCPU-UsageEX
              - cpu-TemperatureEX
              - systemTemperatureEX
              - enclosureSystemTemp
              - hdTemperatureEX
              - diskSmartInfo
              - ifPacketsReceivedEX
              - ifPacketsSentEX
              - sysVolumeTotalSizeEX
              - sysVolumeFreeSizeEX
              - systemTotalMemEX
              - systemFreeMemEX
              - availablePercent
              - readHitRate
              - writeHitRate
        ```
    1. run the commands [here](https://github.com/prometheus/snmp_exporter/tree/master/generator#running) to create `snmp.yml` (a copy of that file is available [here](snmp.yml), but prefer to regenerate it)

1. Download `snmp_exporter`: from the project [release page](https://github.com/prometheus/snmp_exporter/releases), download the [latest binary release](https://github.com/prometheus/snmp_exporter/releases/download/v0.18.0/snmp_exporter-0.18.0.linux-amd64.tar.gz) (currently at version 0.18.0), for the right architecture (`amd64` most likely), and untar it in a directory on the nas

1. copy `snmp.yml` created 2 steps above into the directory you installed `snmp_exporter`

1. start the exporter: `./snmp_exporter`; a basic init script is available [here](SnmpExporter.sh), if you want to have it started at boot, run
    ```
    $ ln -s /etc/init.d/SnmpExporter.sh /etc/rcS.d/QS116SnmpExporter
    ```

1. add this scraper configuration to `prometheus.yml`
    ```
      - job_name: 'snmp_qnap'
        scrape_interval: 1m
        static_configs:
        - targets:
            - 127.0.0.1
        metrics_path: /snmp
        params:
          module: [qnap]
        relabel_configs:
          - source_labels: [__address__]
            target_label: __param_target
          - source_labels: [__param_target]
            target_label: instance
          - target_label: __address__
            replacement: 127.0.0.1:9116
    ```
   and restart prometheus; you can verify if it's working correctly in the Status > Targets page of prometheus (ipaddress:9090), or on the log for `snmp_exporter`.

1. if you want you can now install [this](https://grafana.com/grafana/dashboards/9330) grafana dashboard (most of the configuration in the scraper/exporter are so that this dashboard works), set the _Device_ at the top-left to `127.0.0.1` and see if all works properly.


there are probably a lot of other interesting nodes in that MIB (i mostly needed to graph the system temperature), but be careful: traversing those SNMP trees is not cheap nor fast, so be aware that: the more nodes you add, the slower the scraping will be (with the above setup, on my machine, the scrape duration for only this exporter is ~10 seconds).

The exporter log (in debug mode) provides the timing it takes to retrieve every node, so you can use that to screen out things you dont need and speed up the process.
