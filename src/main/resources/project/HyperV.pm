# -------------------------------------------------------------------------
# Package
#    HyperV.pm
#
# Dependencies
#    Win32::OLE
#
# Purpose
#    A perl library that encapsulates the logic to manipulate virtual machines in Hyper-V server using WMI and Hyper-V WMI Provider
# -------------------------------------------------------------------------

package HyperV;

# -------------------------------------------------------------------------
# Includes
# -------------------------------------------------------------------------
use warnings;
use strict;
use Win32::OLE;
use Encode;
use utf8;
use open IO => ':encoding(utf8)';

# -------------------------------------------------------------------------
# Constants
# -------------------------------------------------------------------------
use constant {
	SUCCESS => 0,
	ERROR   => 1,
	
	FALSE => 0,
	TRUE  => 1,
	
	DEFAULT_DEBUG     => 1,
	DEFAULT_SLEEP     => 5,
	DEFAULT_TIMEOUT   => 60,
	DEFAULT_NAMESPACE => 'root\virtualization',
	
	ENABLED  => 2,
	DISABLED => 3,
	
	JOB_SUCCESS         => 0,
	JOB_STARTING        => 3,
	JOB_RUNNING         => 4,
	JOB_COMPLETED       => 7,
	JOB_STARTED         => 4096,
	FAILED              => 32768,
	ACCESS_DENIED       => 32769,
	NOT_SUPPORTED       => 32770,
	UNKNOWN_STATUS      => 32771,
	TIMEOUT             => 32772,
	INVALID_PARAMETER   => 32773,
	SYSTEM_IN_USE       => 32774,
	INVALID_STATE       => 32775,
	INCORRECT_DATA_TYPE => 32776,
	NOT_AVAILABLE       => 32777,
	OUT_OF_MEMORY       => 32778,
	FILE_NOT_FOUND      => 32779,
	NOT_READY           => 32780,
	MACHINE_LOCKED      => 32781,
	SHUTDOWN_PROGRESS   => 32782,
};

################################
# new - Object constructor for HyperV
#
# Arguments:
#   opts hash
#
# Returns:
#   none
#
################################
sub new {
	my ( $class, $opts ) = @_;
	my $self = { _opts => $opts, };
	bless $self, $class;
}

################################
# opts - Get opts hash
#
# Arguments:
#   none
#
# Returns:
#   opts hash
#
################################
sub opts {
	my ($self) = @_;
	return $self->{_opts};
}

################################
# ecode - Get exit code
#
# Arguments:
#   none
#
# Returns:
#   exit code number
#
################################
sub ecode {
	my ($self) = @_;
	return $self->opts()->{exitcode};
}

################################
# initialize - Set initial values
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub initialize {
	my ($self) = @_;
	
	# Set defaults 
	$self->opts->{Debug} = DEFAULT_DEBUG;
	$self->opts->{exitcode} = SUCCESS;
	
	if(defined($self->opts->{hyperv_namespace}) && $self->opts->{hyperv_namespace} eq '') {
		$self->opts->{hyperv_namespace} = DEFAULT_NAMESPACE;
	}
}

################################
# poweron - Power on the specified virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub poweron {
	my ($self) = @_;
	
	$self->initialize();
	
	if ($::gRunTestUseFakeOutput) {
		# Create and return fake output
		my $out = "";
		$out .= "Connecting to Hyper-V server...";
		$out .= "\n";
		$out .= "Conected";
		$out .= "\n";
		$out .= "Powering on virtual machine '".$self->opts->{hyperv_vmname}."'...";
		$out .= "\n";
		$out .= "Successfully powered on virtual machine '".$self->opts->{hyperv_vmname}."'";
		return $out;
	}
	
	$self->debugMsg(1, 'Connecting to Hyper-V server...');
	
	# Get Locator instance
	Win32::OLE->Option(Warn => 0);
	my $wmiLocator = Win32::OLE->new('WbemScripting.SWbemLocator');
	
	# Connect to the Hyper-V server
	my $wmiService = $wmiLocator->ConnectServer($self->opts->{hyperv_host}, $self->opts->{hyperv_namespace}, $self->opts->{hyperv_user}, $self->opts->{hyperv_pass});

	# Check if successful connection    
	if(!defined($wmiService)) {
	    $self->debugMsg(0, 'An error ocurred when connecting to Hyper-V server');
	    $self->opts->{exitcode} = ERROR;
		return;
	}
	
	$self->debugMsg(1, 'Connected');
	$self->debugMsg(1, 'Powering on virtual machine \''.$self->opts->{hyperv_vmname}.'\'...');
	
	# Query for the specific virtual machine to power on
	my $items = $wmiService->ExecQuery('SELECT * FROM Msvm_ComputerSystem WHERE ElementName=\'' . $self->opts->{hyperv_vmname} . '\'');
	
	if ($self->empty($items)) {
		$self->debugMsg(0, 'Virtual machine \''.$self->opts->{hyperv_vmname}.'\' does not exist');
		$self->opts->{exitcode} = ERROR;
	    return;
	}
	
	# Power on the virtual machine
	foreach my $item (in $items) {
		
		# Check if vm already powered on
		if ($item->{EnabledState} == ENABLED) {
			$self->debugMsg(0, 'Virtual machine \''.$self->opts->{hyperv_vmname}.'\' is already powered on');
			return;
		}
		
	    my $result = $item->RequestStateChange(ENABLED);
	    
	    if ($result != JOB_SUCCESS) {
	    	if($result == JOB_STARTED) {
	    		$self->debugMsg(0, 'Power on job started in Hyper-V server');
	    		return;
	    	}
	    	$self->print_error($result);
			return;
		}
	}
	
	# Wait vm to be powered on
	$self->wait_state($wmiService, ENABLED);
	if($self->ecode) { return; }
	
	$self->debugMsg(0, 'Successfully powered on virtual machine \''.$self->opts->{hyperv_vmname}.'\'');
}

################################
# shutdown - Connects to Hyper-V server and calls shutdown_vm 
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub shutdown {
	my ($self) = @_;
	
	$self->initialize();
	
	if ($::gRunTestUseFakeOutput) {
		# Create and return fake output
		my $out = "";
		$out .= "Connecting to Hyper-V server...";
		$out .= "\n";
		$out .= "Conected";
		$out .= "\n";
		$out .= "Shutting down virtual machine '".$self->opts->{hyperv_vmname}."'...";
		$out .= "\n";
		$out .= "Successfully shut down virtual machine '".$self->opts->{hyperv_vmname}."'";
		return $out;
	}
	
	$self->debugMsg(1, 'Connecting to Hyper-V server...');
	
	# Get Locator instance
	Win32::OLE->Option(Warn => 0);
	my $wmiLocator = Win32::OLE->new('WbemScripting.SWbemLocator');
	
	# Connect to the Hyper-V server
	my $wmiService = $wmiLocator->ConnectServer($self->opts->{hyperv_host}, $self->opts->{hyperv_namespace}, $self->opts->{hyperv_user}, $self->opts->{hyperv_pass});
	
	# Check if successful connection    
	if(!defined($wmiService)) {
	    $self->debugMsg(0, 'An error ocurred when connecting to Hyper-V server');
	    $self->opts->{exitcode} = ERROR;
		return;
	}
	
	$self->debugMsg(1, 'Connected');
	
	# Call shutdown_vm
	$self->shutdown_vm($wmiService);
	if($self->ecode) { return; }
}

################################
# shutdown_vm - Shutdown the specified virtual machine
#
# Arguments:
#   wmiService - wmi service to perform operations
#
# Returns:
#   none
#
################################
sub shutdown_vm {
	my ($self, $wmiService) = @_;
	
	$self->debugMsg(1, 'Shutting down virtual machine \''.$self->opts->{hyperv_vmname}.'\'...');
	
	# Query for the specific virtual machine to shutdown
	my $items = $wmiService->ExecQuery('SELECT * FROM Msvm_ComputerSystem WHERE ElementName=\'' . $self->opts->{hyperv_vmname} . '\'');
	
	if ($self->empty($items)) {
		$self->debugMsg(0, 'Virtual machine \''.$self->opts->{hyperv_vmname}.'\' does not exist');
		$self->opts->{exitcode} = ERROR;
	    return;
	}
	
	foreach my $item (in $items) {
		
		# Check if vm already powered on
		if ($item->{EnabledState} == DISABLED) {
			$self->debugMsg(0, 'Virtual machine \''.$self->opts->{hyperv_vmname}.'\' is already powered off');
			return;
		}
		
	   	# Get the GUID for the virtual machine to shutdown
	    my $vmGuid = $item->{Name};

	    # Query for the MSVM_ShutdownComponent that corresponds to the VM GUID
	    my $shutdownList = $wmiService->ExecQuery('SELECT * FROM Msvm_ShutdownComponent WHERE SystemName=\'' . $vmGuid . '\'');
	    
	    if ($self->empty($shutdownList)) {
			$self->debugMsg(0, 'There are no shutdown components for virtual machine \''.$self->opts->{hyperv_vmname}.'\'');
			$self->opts->{exitcode} = ERROR;
		    return;
		}

	    foreach my $shutdownComponent (in $shutdownList) {
	        # Request a shutdown
	        my $result = $shutdownComponent->InitiateShutdown(1, 'no comment');
	        
	        if ($result != JOB_SUCCESS) {
		    	if($result == JOB_STARTED) {
		    		$self->debugMsg(0, 'Shut down job started in Hyper-V server');
		    		return;
		    	}
		    	$self->print_error($result);
				return;
			}
	    }
	}
	
	# Wait vm to be powered off
	$self->wait_state($wmiService, DISABLED);
	if($self->ecode) { return; }
	
	$self->debugMsg(0, 'Successfully shut down virtual machine \''.$self->opts->{hyperv_vmname}.'\'');
}

################################
# revert - Revert a virtual machine to the specified snapshot
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub revert {
	my ($self) = @_;
	my $items;
	
	$self->initialize();
	
	if ($::gRunTestUseFakeOutput) {
		# Create and return fake output
		my $out = "";
		$out .= "Connecting to Hyper-V server...";
		$out .= "\n";
		$out .= "Conected";
		$out .= "\n";
		$out .= "Reverting virtual machine '".$self->opts->{hyperv_vmname}."' to snapshot '".$self->opts->{hyperv_snapshotname}."'...";
		$out .= "\n";
		$out .= "Successfully reverted virtual machine '".$self->opts->{hyperv_vmname}."' to snapshot '".$self->opts->{hyperv_snapshotname}."'";
		return $out;
	}
	
	$self->debugMsg(1, 'Connecting to Hyper-V server...');
	
	# Get Locator instance
	Win32::OLE->Option(Warn => 0);
	my $wmiLocator = Win32::OLE->new('WbemScripting.SWbemLocator');
	
	# Connect to the Hyper-V server
	my $wmiService = $wmiLocator->ConnectServer($self->opts->{hyperv_host}, $self->opts->{hyperv_namespace}, $self->opts->{hyperv_user}, $self->opts->{hyperv_pass});
	
	# Check if successful connection    
	if(!defined($wmiService)) {
	    $self->debugMsg(0, 'An error ocurred when connecting to Hyper-V server');
	    $self->opts->{exitcode} = ERROR;
		return;
	}
	
	$self->debugMsg(1, 'Connected');
	
	# Get vm
	my $vm;
	$items = $wmiService->ExecQuery('SELECT * FROM Msvm_ComputerSystem WHERE ElementName=\'' . $self->opts->{hyperv_vmname} . '\'');
	if ($self->empty($items)) {
		$self->debugMsg(0, 'Virtual machine \''.$self->opts->{hyperv_vmname}.'\' does not exist');
		$self->opts->{exitcode} = ERROR;
	    return;
	}
	foreach my $item (in $items) { $vm = $item; }
	
	# Get snapshot settings
	my $snapshotSetting;
	$items = $wmiService->ExecQuery('SELECT * FROM Msvm_VirtualSystemSettingData WHERE SystemName=\''.$vm->{Name}.'\' AND SettingType=5 AND ElementName=\'' . $self->opts->{hyperv_snapshotname} . '\'');
	if ($self->empty($items)) {
		$self->debugMsg(0, 'Snapshot \''.$self->opts->{hyperv_snapshotname}.'\' for virtual machine \''.$self->opts->{hyperv_vmname}.'\' does not exist');
		$self->opts->{exitcode} = ERROR;
	    return;
	}
	foreach my $item (in $items) { $snapshotSetting = $item; }
		
	# Get management service
	my $managementService;
	$items = $wmiService->ExecQuery('SELECT * FROM Msvm_VirtualSystemManagementService');
	if ($self->empty($items)) {
		$self->debugMsg(0, 'Unable to get Hyper-V Management Service');
		$self->opts->{exitcode} = ERROR;
	    return;
	}
	foreach my $item (in $items) { $managementService = $item; }
	
	# Call shutdown_vm if needed
	if ($vm->{EnabledState} != DISABLED) {
		$self->shutdown_vm($wmiService);
		if($self->ecode) { return; }
	}
	
	$self->debugMsg(1, 'Reverting virtual machine \''.$self->opts->{hyperv_vmname}.'\' to snapshot \''.$self->opts->{hyperv_snapshotname}.'\'...');
	
	# Apply snapshot to vm
	my $result = $managementService->ApplyVirtualSystemSnapshot($vm->Path_->Path, $snapshotSetting->Path_->Path);
	
	if ($result != JOB_SUCCESS) {
    	if($result == JOB_STARTED) {
    		$self->debugMsg(0, 'Apply snapshot job started in Hyper-V server');
    		return;
    	}
    	$self->print_error($result);
		return;
	}
    # PowerOn virtual machine
    $self->poweron();
	
	$self->debugMsg(0, 'Successfully reverted virtual machine \''.$self->opts->{hyperv_vmname}.'\' to snapshot \''.$self->opts->{hyperv_snapshotname}.'\'');
    
}

################################
# capture - Create a snapshot for the specified virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
################################
sub capture {
	my ($self) = @_;
	my $items;
	my $result;
	
	$self->initialize();
	
	if ($::gRunTestUseFakeOutput) {
		# Create and return fake output
		my $out = "";
		$out .= "Connecting to Hyper-V server...";
		$out .= "\n";
		$out .= "Conected";
		$out .= "\n";
		$out .= "Creating snapshot '".$self->opts->{hyperv_snapshotname}."' for virtual machine '".$self->opts->{hyperv_vmname}."'...";
		$out .= "\n";
		$out .= "Successfully created snapshot '".$self->opts->{hyperv_snapshotname}."' for virtual machine '".$self->opts->{hyperv_vmname}."'";
		return $out;
	}
	
	$self->debugMsg(1, 'Connecting to Hyper-V server...');
	
	# Get Locator instance
	Win32::OLE->Option(Warn => 0);
	my $wmiLocator = Win32::OLE->new('WbemScripting.SWbemLocator');
	
	# Connect to the Hyper-V server
	my $wmiService = $wmiLocator->ConnectServer($self->opts->{hyperv_host}, $self->opts->{hyperv_namespace}, $self->opts->{hyperv_user}, $self->opts->{hyperv_pass});
	
	# Check if successful connection    
	if(!defined($wmiService)) {
	    $self->debugMsg(0, 'An error ocurred when connecting to Hyper-V server');
	    $self->opts->{exitcode} = ERROR;
		return;
	}
	
	$self->debugMsg(1, 'Connected');
	
	# Get vm
	my $vm;
	$items = $wmiService->ExecQuery('SELECT * FROM Msvm_ComputerSystem WHERE ElementName=\'' . $self->opts->{hyperv_vmname} . '\'');
	if ($self->empty($items)) {
		$self->debugMsg(0, 'Virtual machine \''.$self->opts->{hyperv_vmname}.'\' does not exist');
		$self->opts->{exitcode} = ERROR;
	    return;
	}
	foreach my $item (in $items) { $vm = $item; }
	
	# Get management service
	my $managementService;
	$items = $wmiService->ExecQuery('SELECT * FROM Msvm_VirtualSystemManagementService');
	if ($self->empty($items)) {
		$self->debugMsg(0, 'Unable to get Hyper-V Management Service');
		$self->opts->{exitcode} = ERROR;
	    return;
	}
	foreach my $item (in $items) { $managementService = $item; }
	
	# Create snapshot
	$self->debugMsg(1, 'Creating snapshot \''.$self->opts->{hyperv_snapshotname}.'\' for virtual machine \''.$self->opts->{hyperv_vmname}.'\'...');
	
	# Create input parameters
	my $objInParam = $managementService->Methods_("CreateVirtualSystemSnapshot")->InParameters->SpawnInstance_();
	$objInParam->{SourceSystem} = $vm->Path_->Path;
	
	# Call to create snapshot
	$result = $managementService->ExecMethod_("CreateVirtualSystemSnapshot", $objInParam);
	
	if ($result != JOB_SUCCESS) {
		if ($result->{ReturnValue} == JOB_STARTED) {
		    $self->debugMsg(1, 'Create snapshot job started in Hyper-V server');
		    
		    # Wait for job to finish
		    my $job;
		    while(TRUE) {
		        $job = $wmiService->Get($result->{Job});
		        if($job->{JobState} != JOB_STARTING && $job->{JobState} != JOB_RUNNING) {
		            last;
		        }
		        sleep(DEFAULT_SLEEP);
		    }
		
		    if($job->{JobState} != JOB_COMPLETED) {
		        $self->debugMsg(0, 'An error occured when creating snapshot:');
		        $self->debugMsg(0, 'Error code:' . $job->{ErrorCode});
		        $self->debugMsg(0, 'Error description:' . $job->{ErrorDescription});
		        $self->opts->{exitcode} = ERROR;
		        return;
		    }
		}
		else {
			$self->print_error($result);
			return;
		}
	}
	
	# Get last snapshot
	my $snapshotSetting;
	while(TRUE) {
		$items = $wmiService->ExecQuery("ASSOCIATORS OF {".$vm->{Path_}->{Path}."} WHERE resultClass = Msvm_VirtualSystemsettingData AssocClass = Msvm_PreviousSettingData");
		foreach my $item (in $items) { $snapshotSetting = $item; }
		
		if (!$self->empty($items)) {
			last;
		}
		sleep(DEFAULT_SLEEP);
	}
	
	# Set snapshot name
	$snapshotSetting->{ElementName} = $self->opts->{hyperv_snapshotname};
	$result = $managementService->ModifyVirtualSystem($vm->Path_->Path, $snapshotSetting->GetText_(1));
	if ($result != JOB_SUCCESS) {
    	if($result == JOB_STARTED) {
    		$self->debugMsg(0, 'Set name job started in Hyper-V server');
    		return;
    	}
    	$self->print_error($result);
		return;
	}
	
	$self->debugMsg(0, 'Successfully created snapshot \''.$self->opts->{hyperv_snapshotname}.'\' for virtual machine \''.$self->opts->{hyperv_vmname}.'\'');
}

# -------------------------------------------------------------------------
# Helper functions
# -------------------------------------------------------------------------

################################
# wait_state - Wait until vm is in the desired state
#
# Arguments:
#   wmiService - wmi service to perform operations
#   state      - desired state
#
# Returns:
#   none
#
################################
sub wait_state {
	my ($self, $wmiService, $state) = @_;
	my $items;
	my $vm;
	my $counter = 0;
	
	while(TRUE) {
		# Get vm
		$items = $wmiService->ExecQuery('SELECT * FROM Msvm_ComputerSystem WHERE ElementName=\'' . $self->opts->{hyperv_vmname} . '\'');
		foreach my $item (in $items) { $vm = $item; }
		
		# VM has desired state or timeout
		if($vm->{EnabledState} == $state) {
			last;
		} elsif ($counter >= DEFAULT_TIMEOUT) {
			$self->debugMsg(0, 'Timeout');
			$self->opts->{exitcode} = ERROR;
		    return;
		}

		$counter++;
		sleep(DEFAULT_SLEEP);
	}
}

################################
# print_error - Print error message for specified error code
#
# Arguments:
#   result - error code
#
# Returns:
#   none
#
################################
sub print_error {
	my ($self, $result) = @_;
	
	$self->debugMsg(0, 'An error occured:');
	if ($result == FAILED) {
        $self->debugMsg(0, 'Operation failed');
    } elsif ($result == ACCESS_DENIED) {
        $self->debugMsg(0, 'Access denied');
    } elsif ($result == NOT_SUPPORTED) {
        $self->debugMsg(0, 'Operation not supported');
    } elsif ($result == UNKNOWN_STATUS) {
        $self->debugMsg(0, 'Status is unknown');
    } elsif ($result == TIMEOUT) {
        $self->debugMsg(0, 'Timeout');
    } elsif ($result == INVALID_PARAMETER) {
        $self->debugMsg(0, 'Invalid parameter');
    } elsif ($result == SYSTEM_IN_USE) {
        $self->debugMsg(0, 'System is in use');
    } elsif ($result == INVALID_STATE) {
        $self->debugMsg(0, 'Invalid state for this operation');
    } elsif ($result == INCORRECT_DATA_TYPE) {
        $self->debugMsg(0, 'Incorrect data type');
    } elsif ($result == NOT_AVAILABLE) {
        $self->debugMsg(0, 'System is not available');
    } elsif ($result == OUT_OF_MEMORY) {
        $self->debugMsg(0, 'Out of memory');
    } elsif ($result == FILE_NOT_FOUND) {
        $self->debugMsg(0, 'File not found');
    } elsif ($result == NOT_READY) {
        $self->debugMsg(0, 'The system is not ready');
    } elsif ($result == MACHINE_LOCKED) {
        $self->debugMsg(0, 'The machine is locked and cannot be shut down');
    } elsif ($result == SHUTDOWN_PROGRESS) {
        $self->debugMsg(0, 'A system shutdown is in progress');
    } else {
        $self->debugMsg(0, 'Unknown error');
    }
    $self->opts->{exitcode} = ERROR;
}

################################
# empty - Check if $items is empty
#
# Arguments:
#   items - object collection to check if is empty
#
# Returns:
#   1 - empty
#   0 - not empty
#
################################
sub empty {
	my ($self, $items) = @_;
	my $count = 1;
	
	foreach my $item (in $items) { 
		$count--;
		last; 
	}
	return $count;
}

###############################
# debugMsg - Print a debug message
#
# Arguments:
#   errorlevel - number compared to $self->opts->{Debug}
#   msg        - string message
#
# Returns:
#   none
#
################################
sub debugMsg {
	my ( $self, $errlev, $msg ) = @_;
	if ( $self->opts->{Debug} >= $errlev ) { print "$msg\n"; }
}
