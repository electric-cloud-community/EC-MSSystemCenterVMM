use ElectricCommander;
use File::Basename;
use ElectricCommander::PropDB;
use ElectricCommander::PropMod;
use Encode;
use utf8;
use open IO => ':encoding(utf8)';

$|=1;

use constant {
	SUCCESS => 0,
	ERROR   => 1,
};

# Create ElectricCommander instance
my $ec = new ElectricCommander();
$ec->abortOnError(0);

if(defined($opts->{connection_config}) && $opts->{connection_config} ne "") {
	my $cfgName = $opts->{connection_config};
	print "Loading config $cfgName\n";
	
	my $proj = "$[/myProject/projectName]";
	my $cfg = new ElectricCommander::PropDB($ec,"/projects/$proj/hyperv_cfgs");
	
	my %vals = $cfg->getRow($cfgName);
	
	# Check if configuration exists
	unless(keys(%vals)) {
		print "Configuration [$cfgName] does not exist\n";
	    exit ERROR;
	}
	
	# Add all options from configuration
	foreach my $c (keys %vals) {
	    print "Adding config $c = $vals{$c}\n";
	    $opts->{$c}=$vals{$c};
	}
	
	# Check that credential item exists
	if (!defined $opts->{credential} || $opts->{credential} eq "") {
	    print "Configuration [$cfgName] does not contain an Hyper-V credential\n";
	    exit ERROR;
	}
	# Get user/password out of credential named in $opts->{credential}
	my $xpath = $ec->getFullCredential("$opts->{credential}");
	$opts->{hyperv_user} = $xpath->findvalue("//userName");
	$opts->{hyperv_pass} = $xpath->findvalue("//password");
	
	# Check for required items
	if (!defined $opts->{hyperv_host} || $opts->{hyperv_host} eq "") {
	    print "Configuration [$cfgName] does not contain an Hyper-V server hostname\n";
	    exit ERROR;
	}
    if (!defined $opts->{hyperv_user} || $opts->{hyperv_user} eq "") {
	    print "Credential [$cfgName] does not contain an Hyper-V username\n";
	    exit ERROR;
	}
    if (!defined $opts->{hyperv_pass} || $opts->{hyperv_pass} eq "") {
	    print "Credential [$cfgName] does not contain an Hyper-V password\n";
	    exit ERROR;
	}
}

# Load the actual code into this process
if (!ElectricCommander::PropMod::loadPerlCodeFromProperty(
    $ec,'/myProject/hyperv_driver/HyperV') ) {
    print 'Could not load HyperV.pm\n';
    exit ERROR;
}

# Make an instance of the object, passing in options as a hash
my $gt = new HyperV($opts);
