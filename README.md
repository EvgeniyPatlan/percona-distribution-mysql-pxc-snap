# percona-distribution-mysql-pxc

Percona Distribution for MySQL (PXC variant) packaged as a strict-confinement
snap: Percona XtraDB Cluster (Galera) combined with the best components from
the Percona ecosystem, all tested to work together — Percona XtraBackup for
hot physical backups, ProxySQL and HAProxy for load balancing,
replication-manager for asynchronous replica failover between clusters, and
the full Percona Toolkit — staged unmodified from Percona's official apt
repository at `repo.percona.com`, nothing compiled from source. One major
version is currently published, pinned to an exact upstream package version
(see below). Base: `core26`.

## Why this snap

Installing this snap gets a complete, self-contained Percona XtraDB Cluster
node plus the surrounding distribution tooling in one artifact, with every
component pinned to an exact upstream version rather than "whatever is
latest on 8.4". The install hook initializes the data directory and
bootstraps a single-node cluster automatically (`wsrep` enabled, empty
`gcomm://`), and switches `root@localhost` to `auth_socket` authentication,
so there is no separate setup step to get a running node. State Snapshot
Transfer (SST, used when a node joins or rejoins the cluster) is handled
internally by the XtraBackup binary bundled inside the server package itself
(`usr/bin/pxc_extra/pxb-8.4/bin/xtrabackup`, driven by
`wsrep_sst_xtrabackup-v2`) — that is not exposed as a snap app. The
standalone `xtrabackup` app comes from a separately staged
`percona-xtrabackup-84` package and is what you use for ad-hoc hot backups
against the running server (see the how-to below). ProxySQL, HAProxy, and
`garbd` ship as disabled daemons you opt into with `snap start` when you
need them.

## Tracks and branches

| Branch | apt source | Version | Status |
|---|---|---|---|
| `8.4/edge` | `repo.percona.com/pdpxc-84-lts/apt` (resolute, `main`) | 8.4.10-10 | current |

Only one track is published today. Additional tracks will follow upstream
availability.

## Getting the snap

### From a CI build

Every push to a `*/edge` branch, every pull request, and every manual
`workflow_dispatch` run of the `Tests` workflow builds the snap (amd64 and
arm64) and runs the full spread suite against it.

1. Open the workflow run in GitHub Actions and download the
   `snap-packages` artifact.
2. Unzip it.
3. Install:
   ```
   sudo snap install ./percona-distribution-mysql-pxc_<version>_amd64.snap --dangerous --jailmode
   ```
   (substitute the `arm64` filename on that architecture).

### From source

```
git clone https://github.com/EvgeniyPatlan/percona-distribution-mysql-pxc-snap.git
cd percona-distribution-mysql-pxc-snap
git checkout 8.4/edge
snapcraft pack
sudo snap install ./percona-distribution-mysql-pxc_*.snap --dangerous --jailmode
```

Requires the `snapcraft` and `lxd` snaps.

A Store channel exists for the `8.4/edge` track, but the release workflow
only publishes when the repository's `RELEASE_ENABLED` variable is set, so
Store availability isn't guaranteed.

## First steps

`mysqld` starts automatically on install and bootstraps a single-node
cluster. The install hook switches `root@localhost` to `auth_socket`
authentication, so connect locally without a password:

```
sudo percona-distribution-mysql-pxc.mysql -u root
```

A TCP connection as `root@localhost` is denied by design — `auth_socket`
only accepts the local Unix socket — so create a dedicated user with a
password for TCP/network access. To join more nodes, set
`wsrep_cluster_address` in
`/var/snap/percona-distribution-mysql-pxc/current/etc/mysqld.cnf` **before**
restarting `mysqld`; a node that restarts with the default empty `gcomm://`
bootstraps a new single-node cluster instead of rejoining. Cluster traffic
encryption is on by default, so every joining node must share the SSL
certificates auto-generated in the first node's data directory
(`/var/snap/percona-distribution-mysql-pxc/common/data/*.pem`).

## Services and apps

63 apps in total: 21 individual apps plus the 42 Percona Toolkit `pt-*`
tools (grouped below as one row).

| App | Kind | Purpose |
|---|---|---|
| `mysqld` | daemon, auto-started | Cluster node, run under a supervisor loop that re-execs on the SQL `RESTART` statement (exit code 16) |
| `mysql` | CLI | interactive/batch SQL client |
| `mysqladmin` | CLI | server administration (ping, status, shutdown, …) |
| `mysqlcheck` | CLI | table check/repair/analyze/optimize |
| `mysqldump` | CLI | logical backup |
| `mysqlimport` | CLI | load delimited text files |
| `mysqlshow` | CLI | list databases/tables/columns |
| `mysqlslap` | CLI | load-testing/benchmark tool |
| `clustercheck` | CLI | Galera cluster health probe (HTTP-style response body, e.g. `200 OK`) |
| `garbd` | daemon, disabled by default | Galera Arbitrator — a voting-only, dataless cluster member |
| `xtrabackup` | CLI | hot physical backup/restore against this snap's own server |
| `xbstream` | CLI | XtraBackup stream (de)serialization |
| `xbcloud` | CLI | upload/download XtraBackup images to/from cloud storage |
| `xbcrypt` | CLI | encrypt/decrypt XtraBackup stream files |
| `qpress` | CLI | (de)compression used by XtraBackup's compressed backups |
| `proxysql` | daemon, disabled by default | ProxySQL SQL-aware proxy/load balancer |
| `proxysql-admin` | CLI | ProxySQL admin helper |
| `proxysql-status` | CLI | ProxySQL status/health reporting |
| `haproxy` | daemon, disabled by default | HAProxy (TCP mode) load balancer |
| `halog` | CLI | HAProxy log analysis tool |
| `replication-manager` | CLI | asynchronous master-master replication between separate PXC clusters (cron-driven; not exercised by this repo's spread suites — see the how-to below) |
| `pt-align` … `pt-visual-explain` | CLI (42 tools) | Percona Toolkit utilities, run as `percona-distribution-mysql-pxc.pt-<tool>` |

`mysqld` is the only daemon enabled by default:

```
sudo snap stop percona-distribution-mysql-pxc.mysqld
sudo snap start percona-distribution-mysql-pxc.mysqld
sudo snap restart percona-distribution-mysql-pxc.mysqld
```

`garbd`, `proxysql`, and `haproxy` ship `install-mode: disable` — they exist
on disk after install but are not running until you `snap start` them. This
snap also exposes a `mysql-sockets` content slot (`content:
socket-directory`, read/write on `$SNAP_DATA/run`) for other snaps that need
direct access to the cluster socket.

## Configuration and data paths

| Item | Path |
|---|---|
| Read-only defaults | `/snap/percona-distribution-mysql-pxc/current/etc/my.cnf` (`!includedir` pulls in the directory below) |
| Editable mysqld config | `/var/snap/percona-distribution-mysql-pxc/current/etc/mysqld.cnf` |
| `clustercheck` defaults file | `/var/snap/percona-distribution-mysql-pxc/current/etc/clustercheck.cnf` (written by the install hook: `root` over the local socket) |
| ProxySQL config | `/var/snap/percona-distribution-mysql-pxc/current/etc/proxysql/proxysql.cnf` (seeded once on install; kept out of the directory above because mysqld's `!includedir` would otherwise try — and fail — to parse ProxySQL's brace-block syntax as an ini file, refusing to start with "Found option without preceding group") |
| HAProxy config | `/var/snap/percona-distribution-mysql-pxc/current/etc/haproxy/haproxy.cfg` (seeded once on install with a commented example PXC frontend/backend) |
| Data directory | `/var/snap/percona-distribution-mysql-pxc/common/data` (survives snap refreshes; auto-generated cluster-encryption SSL certificates — `*.pem` — also live here) |
| Error log | `/var/snap/percona-distribution-mysql-pxc/current/log/error.log` |
| Slow / general / binlog logs | `/var/snap/percona-distribution-mysql-pxc/current/log/{mysql-slow,query,mysql-bin}.log` (disabled by default; uncomment the relevant lines in `mysqld.cnf`) |
| Socket | `/var/snap/percona-distribution-mysql-pxc/current/run/mysqld.sock` |
| X Protocol socket | `/var/snap/percona-distribution-mysql-pxc/current/run/mysqlx.sock` (port 33060) |
| ProxySQL data dir | `/var/snap/percona-distribution-mysql-pxc/common/proxysql` (mode 770, seeded by the install hook) |
| HAProxy stats socket | `/var/snap/percona-distribution-mysql-pxc/current/run/haproxy.sock` |

## How-tos

### XtraBackup: hot backup and restore

```
sudo percona-distribution-mysql-pxc.xtrabackup --backup -u root \
  -S /var/snap/percona-distribution-mysql-pxc/current/run/mysqld.sock \
  --datadir=/var/snap/percona-distribution-mysql-pxc/common/data \
  --target-dir=/var/snap/percona-distribution-mysql-pxc/common/backup
sudo percona-distribution-mysql-pxc.xtrabackup --prepare \
  --target-dir=/var/snap/percona-distribution-mysql-pxc/common/backup
```

`--datadir` is required under strict confinement: without it, `xtrabackup`
cannot find the config at its compiled-in search paths. This is the exact
form the CI-proven `backup_restore` spread suite runs.

To restore (also from that suite, adapted for a Galera node): stop
`mysqld`, empty the data directory, then copy back —

```
sudo snap stop percona-distribution-mysql-pxc.mysqld
sudo rm -rf /var/snap/percona-distribution-mysql-pxc/common/data
sudo mkdir /var/snap/percona-distribution-mysql-pxc/common/data
sudo chown snap_daemon:root /var/snap/percona-distribution-mysql-pxc/common/data
# xtrabackup has no setpriv wrapper (unlike mysqld), so --copy-back runs
# confined as its invoking user; the data dir's group needs its own write
# bit or the restore fails with "Permission denied".
sudo chmod g+w /var/snap/percona-distribution-mysql-pxc/common/data
sudo percona-distribution-mysql-pxc.xtrabackup --copy-back \
  --target-dir=/var/snap/percona-distribution-mysql-pxc/common/backup \
  --datadir=/var/snap/percona-distribution-mysql-pxc/common/data
sudo chown -R snap_daemon:root /var/snap/percona-distribution-mysql-pxc/common/data
sudo chmod go-rwx /var/snap/percona-distribution-mysql-pxc/common/data
```

If the restored data directory contains a `grastate.dat`, set
`safe_to_bootstrap: 1` in it before starting `mysqld` again, so the node can
bootstrap a fresh cluster from the restored data.

### ProxySQL quickstart

```
sudo snap start percona-distribution-mysql-pxc.proxysql
```

The admin interface listens on `:6032` and the proxy interface on `:6033`,
both on **all interfaces**. The seeded config ships the default admin
credentials `admin:admin` — **change both before starting on a routable
host**. Config is seeded once, at
`/var/snap/percona-distribution-mysql-pxc/current/etc/proxysql/proxysql.cnf`;
later changes go through the admin interface itself:

```
percona-distribution-mysql-pxc.mysql -h127.0.0.1 -P6032 -uadmin -padmin \
  -e "INSERT INTO mysql_servers (hostgroup_id, hostname, port) VALUES (0, '127.0.0.1', 3306);
      LOAD MYSQL SERVERS TO RUNTIME;"
```

`proxysql-admin` needs `--proxysql-username`/`--proxysql-password` (or a
`proxysql-admin.cnf` passed via `--config-file`), and `proxysql-status`
needs `--login-file` or a `~/.my.cnf` — no default config is shipped for
either.

### HAProxy quickstart

```
sudo snap start percona-distribution-mysql-pxc.haproxy
```

The seeded config at
`/var/snap/percona-distribution-mysql-pxc/current/etc/haproxy/haproxy.cfg`
ships a commented example frontend/backend that health-checks via an
`option httpchk GET /` against `clustercheck` fronted by something like
`socat` on port 9200 — edit it before starting. This repo's own
`haproxy_service` spread suite found that exact pattern race-prone under
confinement (HAProxy can see a TCP RST before consuming the buffered `200
OK` response) and instead proves out a plain L4 connect check directly
against `mysqld` on port 3306:

```
frontend pxc-front
    bind 127.0.0.1:13306
    default_backend pxc-back
backend pxc-back
    server node1 127.0.0.1:3306 check inter 5s downinter 5s rise 2 fall 3
```

`clustercheck`'s own correctness can still be verified directly:
`percona-distribution-mysql-pxc.clustercheck` (no arguments) prints an
HTTP-style response body such as `200 OK` when the node is `Synced` and
part of the `Primary` component.

### garbd (Galera Arbitrator)

`garbd` ships disabled. Configure and start it with `snap set`:

```
sudo snap set percona-distribution-mysql-pxc garbd.address=gcomm://<ip>:4567 garbd.group=<cluster-name>
sudo snap set percona-distribution-mysql-pxc garbd.options="<extra galera options>"   # optional
sudo snap start percona-distribution-mysql-pxc.garbd
```

Both `garbd.address` and `garbd.group` are required — the wrapper exits
with an error if either is unset. This is exercised in CI
(`garbd_membership` suite): starting `garbd` against a running node raises
`wsrep_cluster_size` from 1 to 2, and stopping it shrinks the cluster back
to 1. That suite disables cluster traffic encryption
(`pxc-encrypt-cluster-traffic = OFF`) first for its loopback test — for an
encrypted cluster, distribute the node's SSL certificates to wherever
`garbd` runs.

### replication-manager

`replication-manager` wraps Percona's `replication_manager.sh`, which
manages asynchronous master-master replication between separate PXC
clusters. It expects a `percona` schema with `replication`, `link`,
`cluster`, and `weight` tables (see the script's own header comment for the
DDL), MySQL credentials for the invoking user (e.g. a `~/.my.cnf`, since
this app is not run through the `setpriv` wrapper the rest of this snap
uses), and is designed to run on a schedule rather than once:

```
percona-distribution-mysql-pxc.replication-manager --help
percona-distribution-mysql-pxc.replication-manager --defaults-file=<path to a mysql client config>
```

No spread suite in this repo currently exercises `replication-manager`;
treat the flags above as sourced from the upstream script itself, not
CI-verified for this snap.

### Percona Toolkit

All 42 `pt-*` tools are exposed as individual snap commands, e.g.:

```
sudo percona-distribution-mysql-pxc.pt-summary
sudo percona-distribution-mysql-pxc.pt-query-digest \
  /var/snap/percona-distribution-mysql-pxc/common/slow.log
```

Input files for the toolkit commands must live under
`/var/snap/percona-distribution-mysql-pxc/common` — the snap cannot read
your home directory under strict confinement. Tools run as the invoking
user rather than through a `setpriv` wrapper (so that `auth_socket` sees
the real uid), so use `sudo` when the target account (such as `root`)
relies on `auth_socket` — for example `pt-show-grants`.

> **Under strict confinement, redirecting a snap app's stdout directly to a
> file can silently produce an empty file with exit code 0.** Pipe the
> output through `cat` instead of redirecting it directly — this is the
> CI-proven pattern used in this repo's `cli_mysqldump` suite:
>
> ```
> sudo percona-distribution-mysql-pxc.mysqldump -u root --single-transaction --set-gtid-purged=OFF --databases mydb | cat > backup.sql
> ```

## Testing

Every push and pull request runs the full spread suite against a real
snapd install inside an LXD `ubuntu-24.04` VM, on both `amd64` and
`arm64`. Suites: `aliases`, `backup_restore`, `cli_mysqladmin`,
`cli_mysqlcheck`, `cli_mysqlcli`, `cli_mysqldump`, `cli_mysqlimport`,
`cli_mysqlshow`, `cli_mysqlslap`, `cluster_bootstrap`, `daemon_mysqld`,
`garbd_membership`, `haproxy_service`, `proxysql_service`, `smoke`,
`storage`, and `toolkit_cli` — 17 suites, all run on every push. `upgrade`
is marked `manual: true` (installs from the `8.4/edge` Store channel first,
which is not guaranteed to be published — see `RELEASE_ENABLED` above) and
is excluded from the automatic run. As of the current `8.4/edge` head, all
17 non-manual suites pass in CI on both architectures; this reflects the
latest run, not a permanent guarantee.

To reproduce locally:

```
snapcraft pack
CRAFT_ARTIFACT=$(pwd)/percona-distribution-mysql-pxc_<version>_amd64.snap spread -v
```

(`spread` from `go install github.com/canonical/spread/cmd/spread@latest`;
needs the `lxd` snap.)

## License

The snap packaging is Apache-2.0. Upstream component licenses (Percona
XtraDB Cluster server, client, common, and garbd; Percona XtraBackup;
ProxySQL; HAProxy; Percona Toolkit; and their Perl/util-linux runtime
dependencies) are shipped under `licenses/` inside the snap.
`percona-replication-manager` ships no copyright file in its `.deb`, so no
license file for it is included there.
