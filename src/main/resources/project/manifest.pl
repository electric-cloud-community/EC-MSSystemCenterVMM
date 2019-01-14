@files = (
 ['//property[propertyName="ui_forms"]/propertySheet/property[propertyName="HyperVCreateConfigForm"]/value'  , 'forms/HyperVCreateConfigForm.xml'],
 ['//property[propertyName="ui_forms"]/propertySheet/property[propertyName="HyperVEditConfigForm"]/value'  , 'forms/HyperVEditConfigForm.xml'],
 
 ['//property[propertyName="preamble"]/value' , 'preamble.pl'],
 ['//property[propertyName="HyperV"]/value' , 'HyperV.pm'],
 
 ['//procedure[procedureName="CreateConfiguration"]/step[stepName="CreateConfiguration"]/command' , 'conf/createcfg.pl'],
 ['//procedure[procedureName="CreateConfiguration"]/step[stepName="CreateAndAttachCredential"]/command' , 'conf/createAndAttachCredential.pl'],
 ['//procedure[procedureName="DeleteConfiguration"]/step[stepName="DeleteConfiguration"]/command' , 'conf/deletecfg.pl'],
 
 ['//procedure[procedureName="PowerOn"]/step[stepName="PowerOn"]/command' , 'vm/poweron.pl'],
 ['//procedure[procedureName="Shutdown"]/step[stepName="Shutdown"]/command' , 'vm/shutdown.pl'],
 ['//procedure[procedureName="Revert"]/step[stepName="Revert"]/command' , 'vm/revert.pl'],
 ['//procedure[procedureName="Capture"]/step[stepName="Capture"]/command' , 'vm/capture.pl'],

 ['//property[propertyName="ec_setup"]/value', 'ec_setup.pl'],
);
