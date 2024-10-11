# Azure Resource Group Cleanup Reusable Workflow

This repository provides a reusable GitHub Actions workflow designed to automate the cleanup of resources within a specified Azure Resource Group. The workflow helps maintain a clean and organized Azure environment by ensuring that no resources or dependencies are left behind after cleanup.

## Features

- Reusable Workflow: Easily integrate this workflow into other repositories or projects.
- Resource Cleanup: Deletes all resources within a specified Azure Resource Group, managing dependencies and avoiding deletion errors.
- Error Handling and Logging: Detailed logs and error reporting ensure you are informed about any issues that occur during the cleanup process.
- Compatibility: Works with Azure CLI version 2.30.0 or higher.

## Prerequisites

- Azure CLI: Ensure you have Azure CLI installed and configured (version 2.30.0 or higher).
- Azure Subscription: Your Azure account should have permissions to delete resources in the specified Azure Resource Group.
- GitHub Repository Secrets: If running the workflow via GitHub Actions, configure the required secrets with the necessary Azure credentials.

## Setup and Usage

### 1. Using the Reusable Workflow in Your Repository

You can integrate this reusable workflow into your own repository by referencing it in your GitHub Actions workflow file:

```yaml
jobs:  
  cleanup:  
    uses: maidannikov/yem.workflow.azurergcleanup/.github/workflows/cleanup.yml@master  
    with:  
      resource-group: "ResourceGroupName"  
    secrets:  
      azure-credentials: ${{ secrets.AZURE_CREDENTIALS }}  
```

### 2. Running Locally

If you prefer to run the cleanup script locally, follow these steps:

1. Clone the repository to your local machine.  
2. Execute the cleanup.sh script and specify the name of the Azure Resource Group to be cleaned up.  
3. Check the cleanup.log file for any errors or remaining resources.  

### 3. Running via GitHub Actions

To use the workflow in a repository:

1. Add the following secret to your GitHub repository:  
   - AZURE_CREDENTIALS: Contains your Azure service principal credentials in JSON format.
```json
{
  "clientId": "client-id-of-your-sp",
  "clientSecret": "client-secret-of-your-sp",
  "subscriptionId": "your-subscription-id",
  "tenantId": "your-tenant-id"
}
```
2. Configure the workflow in your repository to reference this reusable workflow.  
3. Trigger the workflow manually, on a schedule, or based on a specific event such as pull requests or pushes.  

## File Descriptions

- **cleanup.sh**: The primary script that performs the resource cleanup. It logs into Azure, validates the CLI version, and deletes resources in a specific order to avoid dependency issues.
- **cleanup.yml**: The reusable GitHub Actions workflow for resource cleanup that can be referenced in other repositories.
- **main.yml**: An additional GitHub Actions workflow included for advanced scenarios such as environment setup or validation tasks.

## Important Notes

- This workflow will permanently delete all resources in the specified Azure Resource Group. Use with caution.  
- Ensure that the target Resource Group does not contain any critical or preserved resources.  

## Logging and Error Handling

All operations are logged into a file named `cleanup.log` in the working directory. If any resources fail to delete, they will be reported at the end of the execution.

## Contributing

Contributions are welcome! Please feel free to open an issue or submit a pull request for any improvements or bug fixes.

## Contact

For more information, please reach out to the project maintainer.
