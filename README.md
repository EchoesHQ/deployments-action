# About

GitHub Action to post [deployment](https://docs.echoeshq.com/deployments) and [deployment status](https://docs.echoeshq.com/change-failure-rate) to Echoes.

---

- [Usage](#usage)
  - [Post a deployment](#post-a-deployment-to-echoes-default)
  - [Post a deployment status](#post-a-deployment-status-to-echoes)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Examples](#examples)
  - [Post a deployment - advanced usage](#post-a-deployment-advanced-usage)
  - [Post a deployment status](#post-a-deployment-status)

## Usage

It requires to set the `ECHOES_API_KEY` environment variable with an [API key](https://docs.echoeshq.com/api-authentication#ZB9nc).

### Post a deployment to Echoes (default):

> [!NOTE]
> The post of a deployment is idempotent.
> Retrying a deployment with the **same payload** and **API key** will result in a single deployment in Echoes.

In default mode, the action expects to work on [tags](https://docs.github.com/en/rest/git/tags?apiVersion=2022-11-28) in order to access a commits list.
If no tags are found, it will fallback to the current commit sha `$GITHUB_SHA` that triggered the workflow. For more information, see [Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows).

> [!Important]
> By default `EchoesHQ/deployments-action` do not require to be used in conjonction with the [`actions/checkout` Action](https://github.com/actions/checkout) because it can fallback to `$GITHUB_SHA`.
> However if you are planning to work with [tags](https://docs.github.com/en/rest/git/tags?apiVersion=2022-11-28) make sure to set the appropriate `actions/checkout` options such as `fetch-depth` and `fetch-tags` to fine tuning to your need.

> [!Warning]
> Not any commits would be of interest. Indeed `Deployments` are used by Echoes to extract some critical information such as Teams and Echoes Labels. Could it be a list of commits extracted from tags, extracted from the `$GITHUB_SHA` or manually provided, those have value for Echoes only if they are attached to a PR that was labeled with [Echoes labels](https://docs.echoeshq.com/categorizing-work). The commits would therefore be properly associated to the work they hold for the team they represent.

```yaml
steps:
    - name: Checkout
      uses: actions/checkout@v3
      with:
        fetch-depth: 0

    - name: Post deploy
        uses: EchoesHQ/deployments-action@v1
        id: post-deploy
        env:
            ECHOES_API_KEY: ${{ secrets.ECHOESHQ_API_KEY }}
```

See [Examples](#examples) below for more details.

### Post a deployment status to Echoes:

```yaml
- name: Post status
    uses: EchoesHQ/deployments-action@v1
    with:
        action-type: post-status
        deployment-id: ${{ steps.post-deploy.outputs.deployment_id }}
        status: ${{ steps.deploy.conclusion == 'success' && 'success' || 'failure' }}
    env:
        ECHOES_API_KEY: ${{ secrets.ECHOESHQ_API_KEY }}
```

## Inputs

```yaml
- name: Post a deployment
  uses: EchoesHQ/deployments-action@v1
  with:
    # Optional. Can either be `post-deploy` or `post-status`. Defaults to `post-deploy`.
    action-type: string
    # Required. Newline-separated list of deliverables the deployment contains (e.g., microservice name, application name). Defaults to repository name.
    deliverables: string
    # Required. Newline-separated list of commits SHA shipped as part of the deployment. Defaults to listing commits between the last 2 tags or as a last fallback $GITHUB_SHA.
    commits: string
    # Optional. Version being deployed.
    version: string
    # Optional. URL related to the deployment: URL to a tag, to an artefact etc. Defaults to ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/releases/tag/${tag}
    url: string
```

```yaml
- name: Post a deployment status
  uses: EchoesHQ/deployments-action@v1
  with:
    # Required.
    action-type: post-status
    # Required. Status of the deployment: `failure` or `success`.
    status: string
    # Required. ID of the deployment.
    deployment-id: string
```

### Outputs

Following outputs are available

| Name            | Type   | Description                                |
| --------------- | ------ | ------------------------------------------ |
| `deployment_id` | String | Deployment ID (`action-type: post-deploy`) |

## Examples

### Post a deployment (advanced usages)

Provide commits and deliverables to override the default behaviour.

```yaml
name: Deployment

on:
  push:
    tags:
      - "*"

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Post deploy to Echoes
        uses: EchoesHQ/deployments-action@v1
        id: post-deploy
        with:
          commits: |-
            c1
            c2
            c3
          deliverables: |-
            d1
            d2
          version: 1.0.0
        env:
          ECHOES_API_KEY: ${{ secrets.ECHOES_API_KEY }}

      - name: Get the deploymentID
        run: echo "The deploymentID is ${{ steps.deploy.outputs.deployment_id }}"

      - name: Deploy routine
        id: deploy
        run: |-
          echo "Deploying something..."
```

### Post a deployment status

```yaml
name: Deployment

on:
  push:
    tags:
      - "*"

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - [...]

      - name: Deploy routine
        id: deploy
        run: |-
          echo "Deploying something..."

      - name: Post deploy status
        uses: EchoesHQ/deployments-action@v1
        with:
          action-type: post-status
          # Grab the deployment_id from the job that was responsible for posting the deployment.
          deployment-id: ${{ steps.post-deploy.outputs.deployment_id }}
          # For instance, determine the final status of the deployment based on the job in charge of performing the deploy.
          status: ${{ steps.deploy.conclusion == 'success' && 'success' || 'failure' }}
        env:
          ECHOES_API_KEY: ${{ secrets.ECHOES_API_KEY }}
```
