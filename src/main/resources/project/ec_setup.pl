# The plugin is being promoted, create a property reference in the server's property sheet
# Data that drives the create step picker registration for this plugin.
my %poweron = (
			   label       => "Microsoft System Center VMM - Power On",
			   procedure   => "PowerOn",
			   description => "Power on a virtual machine.",
			   category    => "Resource Management"
			  );
my %shutdown = (
				label       => "Microsoft System Center VMM - Shut Down",
				procedure   => "Shutdown",
				description => "Shutdown a virtual machine.",
				category    => "Resource Management"
			   );
my %revert = (
			  label       => "Microsoft System Center VMM - Revert",
			  procedure   => "Revert",
			  description => "Revert a virtual machine to a specified snapshot.",
			  category    => "Resource Management"
			 );
my %capture = (
			   label       => "Microsoft System Center VMM - Capture",
			   procedure   => "Capture",
			   description => "Create a snapshot for the specified virtual machine.",
			   category    => "Resource Management"
			  );

@::createStepPickerSteps = (\%poweron, \%shutdown, \%revert, \%capture);


$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-MSSystemCenterVMM - PowerOn");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-MSSystemCenterVMM - Shutdown");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-MSSystemCenterVMM - Revert");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-MSSystemCenterVMM - Capture");

$batch->deleteProperty("/server/ec_customEditors/pickerStep/MS System Center VMM - Power On");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/MS System Center VMM - Shut Down");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/MS System Center VMM - Revert");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/MS System Center VMM - Capture");

$batch->deleteProperty("/server/ec_customEditors/pickerStep/Microsoft System Center VMM - Power On");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Microsoft System Center VMM - Shut Down");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Microsoft System Center VMM - Revert");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Microsoft System Center VMM - Capture");


if ($upgradeAction eq "upgrade") {
    my $query   = $commander->newBatch();
    my $newcfg  = $query->getProperty("/plugins/$pluginName/project/hyperv_cfgs");
    my $oldcfgs = $query->getProperty("/plugins/$otherPluginName/project/hyperv_cfgs");
    my $creds   = $query->getCredentials("\$[/plugins/$otherPluginName]");

    local $self->{abortOnError} = 0;
    $query->submit();

    # if new plugin does not already have cfgs
    if ($query->findvalue($newcfg, "code") eq "NoSuchProperty") {

        # if old cfg has some cfgs to copy
        if ($query->findvalue($oldcfgs, "code") ne "NoSuchProperty") {
            $batch->clone(
                          {
                            path      => "/plugins/$otherPluginName/project/hyperv_cfgs",
                            cloneName => "/plugins/$pluginName/project/hyperv_cfgs"
                          }
                         );
        }
    }

    # Copy configuration credentials and attach them to the appropriate steps
    my $nodes = $query->find($creds);
    if ($nodes) {
        my @nodes = $nodes->findnodes('credential/credentialName');
        for (@nodes) {
            my $cred = $_->string_value;

            # Clone the credential
            $batch->clone(
                          {
                            path      => "/plugins/$otherPluginName/project/credentials/$cred",
                            cloneName => "/plugins/$pluginName/project/credentials/$cred"
                          }
                         );

            # Make sure the credential has an ACL entry for the new project principal
            my $xpath = $commander->getAclEntry(
                                                "user",
                                                "project: $pluginName",
                                                {
                                                   projectName    => $otherPluginName,
                                                   credentialName => $cred
                                                }
                                               );
            if ($xpath->findvalue("//code") eq "NoSuchAclEntry") {
                $batch->deleteAclEntry(
                                       "user",
                                       "project: $otherPluginName",
                                       {
                                          projectName    => $pluginName,
                                          credentialName => $cred
                                       }
                                      );
                $batch->createAclEntry(
                                       "user",
                                       "project: $pluginName",
                                       {
                                          projectName                => $pluginName,
                                          credentialName             => $cred,
                                          readPrivilege              => 'allow',
                                          modifyPrivilege            => 'allow',
                                          executePrivilege           => 'allow',
                                          changePermissionsPrivilege => 'allow'
                                       }
                                      );
            }

            # Attach the credential to the appropriate steps
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'PowerOn',
                                        stepName      => 'PowerOn'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'Shutdown',
                                        stepName      => 'Shutdown'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'Revert',
                                        stepName      => 'Revert'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'Capture',
                                        stepName      => 'Capture'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'CreateConfiguration',
                                        stepName      => 'CreateConfiguration'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'CreateConfiguration',
                                        stepName      => 'CreateAndAttachCredential'
                                     }
                                    );
        }
    }
}
