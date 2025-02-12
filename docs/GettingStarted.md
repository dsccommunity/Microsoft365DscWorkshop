# The quick guide to the Microsoft365DscWorkshop

You have completed the getting started guide. You now have an Azure tenant under source control. To follow DevOps best practices, all changes to your Azure tenant should be made through the pipelines you have set up. This ensures that all changes are tracked, repeatable, and can be rolled back if necessary.

From now on, you should:

1. **Make Changes in Source Control**: Any configuration changes should be made in the YAML files within your repository. This ensures that all changes are versioned and can be reviewed through pull requests.
2. **Run Pipelines for Deployment**: Use the Azure DevOps pipelines to apply changes to your Azure tenant. This ensures that the desired state defined in your YAML files is enforced.
3. **Monitor and Validate**: Regularly monitor the pipeline runs and validate that the deployments are successful. The validation stage in your pipeline will help ensure that the current state matches the desired state.
4. **Iterate and Improve**: Continuously improve your configurations and pipelines. As you become more familiar with Microsoft365DSC and Azure DevOps, you can add more automation and checks to your processes.

By following these practices, you will maintain a consistent and reliable configuration for your Azure tenant, leveraging the power of DevOps and infrastructure as code.
