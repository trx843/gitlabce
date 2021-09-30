---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
disqus_identifier: 'https://docs.gitlab.com/ee/workflow/repository_mirroring.html'
---

# Push to a remote repository

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/40137) in GitLab 13.5: LFS support over HTTPS.

For an existing project, you can set up push mirroring as follows:

1. In your project, go to **Settings > Repository**, and then expand the **Mirroring repositories** section.
1. Enter a repository URL.
1. In the **Mirror direction** dropdown, select **Push**.
1. Select an authentication method from the **Authentication method** dropdown.
   You can authenticate with either a password or an [SSH key](index.md#ssh-authentication).
1. Select the **Only mirror protected branches** checkbox, if necessary.
1. Select the **Keep divergent refs** checkbox, if desired.
1. Select **Mirror repository** to save the configuration.

When push mirroring is enabled, only push commits directly to the mirrored repository to prevent the
mirror diverging.

Unlike [pull mirroring](pull.md), the mirrored repository is not periodically auto-synced.
The mirrored repository receives all changes only when:

- Commits are pushed to GitLab.
- A [forced update](index.md#force-an-update) is initiated.

Changes pushed to files in the repository are automatically pushed to the remote mirror at least:

- Within five minutes of being received.
- Within one minute if **Only mirror protected branches** is enabled.

In the case of a diverged branch, an error displays in the **Mirroring repositories**
section.

## Configure push mirrors through the API

You can also create and modify project push mirrors through the
[remote mirrors API](../../../../api/remote_mirrors.md).

## Keep divergent refs

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/208828) in GitLab 13.0.

By default, if any ref (branch or tag) on the remote mirror has diverged from the local repository, the local differences are forced to the remote.

For example, if a repository has `main` and `develop` branches that
have been mirrored to a remote, and then a new commit is added to `develop` on
the remote mirror. The next push updates all of the references on the remote mirror to match
the local repository, and the new commit added to the remote `develop` branch is lost.

With the **Keep divergent refs** option enabled, the `develop` branch is
skipped, causing only `main` to be updated. The mirror status
reflects that `develop` has diverged and was skipped, and be marked as a
failed update. Refs that exist in the mirror repository but not in the local
repository are left untouched.

NOTE:
After the mirror is created, this option can only be modified via the [API](../../../../api/remote_mirrors.md).

## Set up a push mirror from GitLab to GitHub

To set up a mirror from GitLab to GitHub, you must follow these steps:

1. Create a [GitHub personal access token](https://docs.github.com/en/github/authenticating-to-github/keeping-your-account-and-data-secure/creating-a-personal-access-token) with the `public_repo` box checked.
1. Fill in the **Git repository URL** field using this format: `https://<your_github_username>@github.com/<your_github_group>/<your_github_project>.git`.
1. Fill in **Password** field with your GitHub personal access token.
1. Select **Mirror repository**.

The mirrored repository is listed. For example, `https://*****:*****@github.com/<your_github_group>/<your_github_project>.git`.

The repository pushes shortly thereafter. To force a push, select the **Update now** (**{retry}**) button.

## Set up a push mirror from GitLab to AWS CodeCommit

AWS CodeCommit push mirroring is the best way to connect GitLab repositories to
AWS CodePipeline, as GitLab isn't yet supported as one of their Source Code Management (SCM) providers.

Each new AWS CodePipeline needs significant AWS infrastructure setup. It also
requires an individual pipeline per branch.

If AWS CodeDeploy is the final step of a CodePipeline, you can, instead, leverage
GitLab CI/CD pipelines and use the AWS CLI in the final job in `.gitlab-ci.yml`
to deploy to CodeDeploy.

NOTE:
GitLab-to-AWS-CodeCommit push mirroring cannot use SSH authentication until [GitLab issue 34014](https://gitlab.com/gitlab-org/gitlab/-/issues/34014) is resolved.

To set up a mirror from GitLab to AWS CodeCommit:

1. In the AWS IAM console, create an IAM user.
1. Add the following least privileges permissions for repository mirroring as an "inline policy".

   The Amazon Resource Names (ARNs) must explicitly include the region and account. The IAM policy
   below grants privilege for mirroring access to two sample repositories. These permissions have
   been tested to be the minimum (least privileged) required for mirroring:

   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Sid": "MinimumGitLabPushMirroringPermissions",
               "Effect": "Allow",
               "Action": [
                   "codecommit:GitPull",
                   "codecommit:GitPush"
               ],
               "Resource": [
                 "arn:aws:codecommit:us-east-1:111111111111:MyDestinationRepo",
                 "arn:aws:codecommit:us-east-1:111111111111:MyDemo*"
               ]
           }
       ]
   }
   ```

1. After the user was created, select the AWS IAM user name.
1. Select the **Security credentials** tab.
1. Under **HTTPS Git credentials for AWS CodeCommit** select **Generate credentials**.

   NOTE:
   This Git user ID and password is specific to communicating with CodeCommit. Do
   not confuse it with the IAM user ID or AWS keys of this user.

1. Copy or download special Git HTTPS user ID and password.
1. In the AWS CodeCommit console, create a new repository to mirror from your GitLab repository.
1. Open your new repository, and then select **Clone URL > Clone HTTPS** (not **Clone HTTPS (GRC)**).
1. In GitLab, open the repository to be push-mirrored.
1. Go to **Settings > Repository**, and then expand **Mirroring repositories**.
1. Fill in the **Git repository URL** field using this format:

   ```plaintext
   https://<your_aws_git_userid>@git-codecommit.<aws-region>.amazonaws.com/v1/repos/<your_codecommit_repo>
   ```

   Replace `<your_aws_git_userid>` with the AWS **special HTTPS Git user ID** from the IAM Git
   credentials created earlier. Replace `<your_codecommit_repo>` with the name of your repository in CodeCommit.

1. For **Mirror direction**, select **Push**.
1. For **Authentication method**, select **Password** and fill in the **Password** field with the special IAM Git clone user ID **password** created earlier in AWS.
1. The option **Only mirror protected branches** should be good for CodeCommit as it pushes more
   frequently (from every five minutes to every minute).
   CodePipeline requires individual pipeline setups for named branches you wish to have a AWS CI setup for. Because feature branches that have dynamic names are unsupported, configuring **Only mirror protected branches** doesn't cause flexibility problems with CodePipeline integration as long as you are also willing to protect all the named branches you want to build CodePipelines for.

1. Select **Mirror repository**. You should see the mirrored repository appear:

   ```plaintext
   https://*****:*****@git-codecommit.<aws-region>.amazonaws.com/v1/repos/<your_codecommit_repo>
   ```

To test mirroring by forcing a push, select the half-circle arrows button (hover text is **Update now**).
If **Last successful update** shows a date, you have configured mirroring correctly.
If it isn't working correctly, a red `error` tag appears and shows the error message as hover text.

## Set up a push mirror to another GitLab instance with 2FA activated

1. On the destination GitLab instance, create a [personal access token](../../../profile/personal_access_tokens.md) with `write_repository` scope.
1. On the source GitLab instance:
   1. Fill in the **Git repository URL** field using this format: `https://oauth2@<destination host>/<your_gitlab_group_or_name>/<your_gitlab_project>.git`.
   1. Fill in the **Password** field with the GitLab personal access token created on the destination GitLab instance.
   1. Select **Mirror repository**.