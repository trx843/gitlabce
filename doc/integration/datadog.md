---
stage: Create
group: Ecosystem
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Datadog integration **(FREE)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/270123) in GitLab 14.1

This integration allows sending CI/CD pipeline and job information to [Datadog](https://www.datadoghq.com/) for monitoring and troubleshooting of job failures and performance issues using the [CI Visibility](https://app.datadoghq.com/ci) product.

You can find out more information on [Datadog's CI Visibility documentation site](https://docs.datadoghq.com/continuous_integration/).

## How to configure it

The integration is based on [Webhooks](../user/project/integrations/webhooks.md) and it only requires setup on GitLab.

Configure the integration on a project or group by going to **Settings > Integrations > Datadog** for each project or group you want to instrument. You can also activate the integration for the entire GitLab instance.

Fill in the integration configuration settings:

- `Active` enables the integration.
- `Datadog site` specifies which [Datadog site](https://docs.datadoghq.com/getting_started/site/) to send data to.
- `API URL` (optional) allows overriding the API URL used for sending data directly, only used in advanced scenarios.
- `API key` specifies which API key to use when sending data. You can generate one in the [APIs tab](https://app.datadoghq.com/account/settings#api) of the Integrations section on Datadog.
- `Service` (optional) specifies which service name to attach to each span generated by the integration. Use this to differentiate between GitLab instances.
- `Env` (optional) specifies which environment (`env` tag) to attach to each span generated by the integration. Use this to differentiate between groups of GitLab instances (i.e. staging vs production).

You can test the integration with the `Test settings` button. After it’s successful, click `Save changes` to finish the integration set up.

Data sent by the integration will be available in the [CI Visibility](https://app.datadoghq.com/ci) section of your Datadog account.