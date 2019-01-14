##########################
# shutdown.pl
##########################
use warnings;
use strict;
use Encode;
use utf8;
use open IO => ':encoding(utf8)';

my $opts;

$opts->{connection_config} = '$[connection_config]';
$opts->{hyperv_vmname} = '$[hyperv_vmname]';
$opts->{hyperv_namespace} = '$[hyperv_namespace]';

$[/myProject/procedure_helpers/preamble]

$gt->shutdown();
exit($opts->{exitcode});