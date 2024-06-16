<?php
//


$cfg['cgi_config_file']='/u/prog/nagios/etc/cgi.cfg';  // location of the CGI config file

$cfg['cgi_base_url']='/nagios/cgi-bin';


// FILE LOCATION DEFAULTS
$cfg['main_config_file']='/u/prog/nagios/etc/nagios.cfg';  // default location of the main Nagios config file
$cfg['status_file']='/u/prog/nagios/var/status.dat'; // default location of Nagios status file
$cfg['state_retention_file']='/u/prog/nagios/var/retention.dat'; // default location of Nagios retention file



// utilities
require_once(dirname(__FILE__).'/includes/utils.inc.php');

?>
