# Desired State Configuration Basics

## Getting to Know the Syntax

We have already talked about [Microsoft365DSC](https://microsoft365dsc.com/) and you have seen a short demo how it works. Now it is time to get some hands-on experience with that technology.

First let's start with some very basic DSC configuration to get familiar with the syntax.

## Two Terms that should be explained before we start

### What is a DSC Resource?

A **DSC (Desired State Configuration) resource** is a reusable, modular component that defines how to configure a specific aspect of a system (e.g., installing software, managing files, or configuring registry settings). It contains the logic to **test** whether a system is in the desired state and **enforce** that state if deviations exist.

**Importance**: DSC resources enable **infrastructure as code** by ensuring systems remain consistent, compliant, and automatable. They provide **idempotent** configurations (repeatable without side effects), reduce manual errors, and support cross-platform management (Windows/Linux). By standardizing configurations, they prevent configuration drift and streamline large-scale environment management.

### What is a DSC Configuration?

A **DSC (Desired State Configuration) Configuration** is a PowerShell script that defines the **desired state** of a system (e.g., a server or node) using DSC resources. It declares *what* should be configured (not *how*), and when applied, the Local Configuration Manager (LCM) enforces that state.  

#### Key Features

1. **Declarative Syntax**: You define *what* the system should look like (e.g., "install IIS" or "copy files").
2. **Resources**: Uses DSC resources (e.g., `WindowsFeature`, `File`) to enforce specific settings.  
3. **Compilation**: Generates a **MOF (Managed Object Format)** file, which the DSC engine uses to apply the configuration.  
4. **Idempotent**: Safe to run repeatedly - only changes what’s non-compliant.  

#### Why It Matters

- **Consistency**: Ensures all nodes (servers, VMs) adhere to the same baseline.  
- **Automation**: Eliminates manual setup; integrates with DevOps pipelines.  
- **Scalability**: Apply the same configuration to hundreds of nodes.  

When applied, the LCM on the target node reads the MOF file and uses DSC resources to test/enforce the declared state.

## One more thing before we can get started

> :warning: Please open VSCode as admin as we are interacting with the `Program Files` folder.

To use DSC in PowerShell 7, the module [PSDesiredStateConfiguration](https://www.powershellgallery.com/packages/PSDesiredStateConfiguration) is required. Please install it with the following command:

```powershell
Install-Module -Name PSDesiredStateConfiguration -Force
```

## Creating a DSC Configuration

We are going to create a DSC configuration that uses the `File` DSC resource to control a file.

Please create a new file in VSCode named `DscTestFile.ps1` with the following DSC configuration:

```powershell
configuration TestFile1 {
    
    node localhost {
        File TestFile1 {
            Ensure          = 'Present'
            Type            = 'File'
            DestinationPath = 'C:\TestFile1.txt'
            Contents        = 'This is a test file.'
        }
    }
}
```

This configuration must be compiled into a MOF-file first. To do that, just call the configuration like you would call a function and tell it where to put the MOF-file in. You can add the call to the configuration to the same script file.

```powershell
TestFile1 -OutputPath C:\DSC\
```

In the folder `C:\DSC` there should be file file `localhost.mof`. When comparing it to the configuration, it is pretty much the same data but in a very different shape.

The Windows [Local Configuration Manager](https://learn.microsoft.com/en-us/powershell/dsc/managing-nodes/metaconfig?view=dsc-1.1) is the component or service that enacts whatever the configuration instructs it to do. But, it does not understands PowerShell, it understands only MOF.

Next we need to point the [Local Configuration Manager](https://learn.microsoft.com/en-us/powershell/dsc/managing-nodes/metaconfig?view=dsc-1.1) or LCM to the MOF-file. Please run the next command and append it to your script file.

```powershell
Start-DscConfiguration -Path C:\DSC\ -Wait -Verbose -Force
```

When starting the LCM, the output should be like this:

> :information_source: If you do not see any output, please run the `Start-DscConfiguration` command in the Windows PowerShell 5.1.

```text
VERBOSE: Perform operation 'Invoke CimMethod' with following parameters, ''methodName' =
SendConfigurationApply,'className' = MSFT_DSCLocalConfigurationManager,'namespaceName' =                                root/Microsoft/Windows/DesiredStateConfiguration'.                                                                      VERBOSE: An LCM method call arrived from computer t1 with user sid S-1-5-21-2994056205-2466750687-3534442015-500.       VERBOSE: [t1]: LCM:  [ Start  Set      ]                                                                                VERBOSE: [t1]: LCM:  [ Start  Resource ]  [[File]TestFile1]                                                             VERBOSE: [t1]: LCM:  [ Start  Test     ]  [[File]TestFile1]                                                             VERBOSE: [t1]:                            [[File]TestFile1] The system cannot find the file specified.                  VERBOSE: [t1]:                            [[File]TestFile1] The related file/directory is: C:\TestFile1.                VERBOSE: [t1]: LCM:  [ End    Test     ]  [[File]TestFile1]  in 0.0080 seconds.
VERBOSE: [t1]: LCM:  [ Start  Set      ]  [[File]TestFile1]
VERBOSE: [t1]:                            [[File]TestFile1] The system cannot find the file specified.
VERBOSE: [t1]:                            [[File]TestFile1] The related file/directory is: C:\TestFile1.
VERBOSE: [t1]: LCM:  [ End    Set      ]  [[File]TestFile1]  in 0.0000 seconds.
VERBOSE: [t1]: LCM:  [ End    Resource ]  [[File]TestFile1]
VERBOSE: [t1]: LCM:  [ End    Set      ]
VERBOSE: [t1]: LCM:  [ End    Set      ]    in  0.0310 seconds.
VERBOSE: Operation 'Invoke CimMethod' complete.
VERBOSE: Time taken for configuration job to complete is 0.086 seconds
```

:information_source: The script `DscTestFile.ps1` should look like by now:

```powershell
configuration TestFile1 {

    node localhost {

        File TestFile1 {
            Ensure          = 'Present'
            Type            = 'File'
            DestinationPath = 'C:\TestFile1.txt'
            Contents        = 'This is a test file.'
        }

    }

}

TestFile1 -OutputPath C:\DSC\

Start-DscConfiguration -Path C:\DSC\ -Wait -Verbose -Force
```
