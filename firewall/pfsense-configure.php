<?php
/*
 * pfsense-configure.php - configure fw01 (pfSense CE 2.7.2) for the five-zone lab, idempotently.
 * Run on the firewall:  php -f /root/pfsense-configure.php /root/pel.env
 * pel.env (never committed) provides ADMIN_PASS and AUTHKEY (the lab SSH public key).
 *
 * Policy: default deny between zones, least privilege. pfSense rules are stateful and are evaluated
 * on the interface where traffic ENTERS the firewall, first match wins; anything not passed is blocked.
 */
require_once("config.inc");
require_once("functions.inc");
require_once("filter.inc");
require_once("interfaces.inc");
require_once("services.inc");
require_once("system.inc");
require_once("auth.inc");

$env = parse_ini_file($argv[1] ?? "/root/pel.env");
global $config;
$config = parse_config(true);
// empty sections are stored as "" in a factory config; make sure every section we write is an array
foreach (['aliases', 'filter', 'nat', 'syslog', 'dhcpd', 'interfaces', 'system'] as $s) {
    if (!isset($config[$s]) || !is_array($config[$s])) $config[$s] = [];
}
if (!isset($config['nat']['outbound']) || !is_array($config['nat']['outbound'])) $config['nat']['outbound'] = [];
if (!isset($config['system']['ssh']) || !is_array($config['system']['ssh'])) $config['system']['ssh'] = [];

/* ---- system ---- */
$config['system']['hostname'] = 'fw01';
$config['system']['domain'] = 'corp.lab';
$config['system']['timezone'] = 'Asia/Dhaka';
$config['system']['dnsserver'] = ['1.1.1.1', '9.9.9.9'];
$config['system']['webgui']['protocol'] = 'https';
$config['system']['ssh']['enable'] = 'enabled';
$config['system']['ssh']['sshdkeyonly'] = 'enabled';          // keys only, no password logins
$config['system']['sshguard_whitelist'] = '10.0.2.2/32 192.168.10.0/24';
foreach ($config['system']['user'] as &$u) {
    if ($u['name'] === 'admin') {
        $u['bcrypt-hash'] = password_hash($env['ADMIN_PASS'], PASSWORD_BCRYPT);
        unset($u['password'], $u['sha512-hash']);
        $u['authorizedkeys'] = base64_encode(trim($env['AUTHKEY']));
    }
}
unset($u);

/* ---- interfaces: one per zone ---- */
$zones = [
    'lan'  => ['em1', 'MGMT',     '192.168.10.1'],
    'opt1' => ['em2', 'SERVERS',  '192.168.20.1'],
    'opt2' => ['em3', 'USERS',    '192.168.30.1'],
    'opt3' => ['em4', 'SECURITY', '192.168.40.1'],
    'opt4' => ['em5', 'DMZ',      '192.168.50.1'],
];
foreach ($zones as $k => [$dev, $descr, $ip]) {
    $config['interfaces'][$k] = ['enable' => '', 'if' => $dev, 'descr' => $descr,
                                 'ipaddr' => $ip, 'subnet' => '24', 'spoofmac' => ''];
}
// WAN is VirtualBox NAT (10.0.2.0/24): an RFC1918 upstream, so private-network blocking must be off on WAN
unset($config['interfaces']['wan']['blockpriv'], $config['interfaces']['wan']['blockbogons']);
unset($config['interfaces']['lan']['ipaddrv6'], $config['interfaces']['lan']['subnetv6'], $config['interfaces']['lan']['track6-interface'], $config['interfaces']['lan']['track6-prefix-id']);

/* ---- DHCP: only the Users zone gets addresses from the firewall ---- */
$config['dhcpd'] = [
    'opt2' => ['enable' => '', 'range' => ['from' => '192.168.30.100', 'to' => '192.168.30.199'],
               'dnsserver' => ['192.168.20.20'], 'domain' => 'corp.lab', 'gateway' => '192.168.30.1'],
];
unset($config['dhcpdv6']);

/* ---- aliases ---- */
$config['aliases']['alias'] = [
    ['name' => 'PRIVATE_NETS', 'type' => 'network', 'address' => '10.0.0.0/8 172.16.0.0/12 192.168.0.0/16',
     'descr' => 'RFC1918', 'detail' => 'RFC1918||RFC1918||RFC1918'],
    ['name' => 'SRV01', 'type' => 'host', 'address' => '192.168.20.20', 'descr' => 'Ubuntu target server', 'detail' => 'srv01'],
    ['name' => 'MONITOR01', 'type' => 'host', 'address' => '192.168.20.10', 'descr' => 'LibreNMS / Suricata / Wazuh', 'detail' => 'monitor01'],
    ['name' => 'DMZ_WEB01', 'type' => 'host', 'address' => '192.168.50.10', 'descr' => 'DMZ web server', 'detail' => 'dmz-web01'],
    ['name' => 'WEB_PORTS', 'type' => 'port', 'address' => '80 443', 'descr' => 'HTTP/HTTPS', 'detail' => 'http||https'],
    ['name' => 'USER_SRV_PORTS', 'type' => 'port', 'address' => '22 80 443', 'descr' => 'SSH and web on srv01', 'detail' => 'ssh||http||https'],
    ['name' => 'WAZUH_PORTS', 'type' => 'port', 'address' => '1514 1515', 'descr' => 'Wazuh agent', 'detail' => 'events||enrolment'],
];

/* ---- rules ---- */
function r($if, $type, $descr, $src, $dst, $proto = 'any', $port = null, $log = false) {
    static $n = 0;
    $rule = ['type' => $type, 'interface' => $if, 'ipprotocol' => 'inet', 'descr' => $descr,
             'tracker' => (string)(1700000000 + (++$n))];
    if ($proto !== 'any') $rule['protocol'] = $proto;
    if ($proto === 'icmp') $rule['icmptype'] = 'any';
    $rule['source'] = is_array($src) ? $src : ['address' => $src];
    $rule['destination'] = is_array($dst) ? $dst : ['address' => $dst];
    if ($port !== null) $rule['destination']['port'] = $port;
    if ($log) $rule['log'] = '';
    return $rule;
}
$any = ['any' => ''];
$net = fn($if) => ['network' => $if];
$rules = [
    // WAN: only host management through the VirtualBox NAT gateway (lab-only out-of-band access)
    r('wan', 'pass', 'Lab host management (SSH/HTTPS) via VirtualBox NAT', '10.0.2.2', ['network' => 'wanip'], 'tcp', '22', true),
    r('wan', 'pass', 'Lab host management (SSH/HTTPS) via VirtualBox NAT', '10.0.2.2', ['network' => 'wanip'], 'tcp', '443', true),

    // MANAGEMENT: manages everything
    r('lan', 'pass', 'Management may reach all zones and the internet', $net('lan'), $any),

    // SERVERS
    r('opt1', 'pass', 'monitor01 polls devices over SNMPv3', 'MONITOR01', $net('lan'), 'udp', '161'),
    r('opt1', 'pass', 'monitor01 polls the DMZ server over SNMPv3', 'MONITOR01', 'DMZ_WEB01', 'udp', '161'),
    r('opt1', 'pass', 'monitor01 ICMP reachability checks', 'MONITOR01', $any, 'icmp'),
    r('opt1', 'pass', 'monitor01 SSH to network devices', 'MONITOR01', $net('lan'), 'tcp', '22'),
    r('opt1', 'block', 'Servers may not start sessions to other zones', $net('opt1'), 'PRIVATE_NETS', 'any', null, true),
    r('opt1', 'pass', 'Servers to the internet (updates)', $net('opt1'), $any),

    // USERS
    r('opt2', 'pass', 'Users: DNS on srv01', $net('opt2'), 'SRV01', 'tcp/udp', '53'),
    r('opt2', 'pass', 'Users: SSH and web on srv01', $net('opt2'), 'SRV01', 'tcp', 'USER_SRV_PORTS'),
    r('opt2', 'pass', 'Users: web on the DMZ server', $net('opt2'), 'DMZ_WEB01', 'tcp', 'WEB_PORTS'),
    r('opt2', 'pass', 'Users: ping the gateway', $net('opt2'), ['network' => 'opt2ip'], 'icmp'),
    r('opt2', 'block', 'Users may not reach Management or other internal zones', $net('opt2'), 'PRIVATE_NETS', 'any', null, true),
    r('opt2', 'pass', 'Users to the internet', $net('opt2'), $any),

    // SECURITY: authorised test targets only
    r('opt3', 'pass', 'Authorised testing: srv01', $net('opt3'), 'SRV01'),
    r('opt3', 'pass', 'Authorised testing: DMZ web server', $net('opt3'), 'DMZ_WEB01'),
    r('opt3', 'pass', 'Security: ping the gateway', $net('opt3'), ['network' => 'opt3ip'], 'icmp'),
    r('opt3', 'block', 'Security zone may not reach anything else internal', $net('opt3'), 'PRIVATE_NETS', 'any', null, true),
    r('opt3', 'pass', 'Security to the internet (tool updates)', $net('opt3'), $any),

    // DMZ: never reaches Management
    r('opt4', 'pass', 'DMZ web server sends Wazuh events to monitor01', 'DMZ_WEB01', 'MONITOR01', 'tcp', 'WAZUH_PORTS'),
    r('opt4', 'block', 'DMZ must never reach Management', $net('opt4'), $net('lan'), 'any', null, true),
    r('opt4', 'block', 'DMZ may not reach other internal zones', $net('opt4'), 'PRIVATE_NETS', 'any', null, true),
    r('opt4', 'pass', 'DMZ to the internet (updates)', $net('opt4'), $any),
];
$config['filter']['rule'] = $rules;
$config['nat']['outbound']['mode'] = 'automatic';

/* ---- logging: firewall and system logs to monitor01 (Wazuh/rsyslog) ---- */
$config['syslog']['remoteserver'] = '192.168.20.10:514';
$config['syslog']['sourceip'] = 'opt1';
$config['syslog']['ipproto'] = 'ipv4';
$config['syslog']['enable'] = '';
$config['syslog']['logall'] = '';
$config['syslog']['filter'] = '';
$config['syslog']['logdefaultblock'] = '';
$config['syslog']['logdefaultpass'] = '';

write_config("PEL lab: zones, DHCP, aliases, zone policy, remote syslog");
echo "config written\n";
