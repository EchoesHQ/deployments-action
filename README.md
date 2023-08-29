# About

GitHub Action to post deployment and deployment status to Echoes.

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

```yaml
steps:
    - name: Checkout
    uses: actions/checkout@v3
    # In default mode, the action expects to work on tags in order to
    # access a commits list. See Examples below for more details.
    with:
        fetch-depth: 100
        fetch-tags: true

    - name: Post deploy
        uses: EchoesHQ/deployments-action@v1
        id: post-deploy
        env:
            ECHOES_API_KEY: ${{ secrets.ECHOESHQ_API_KEY }}
```

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
    # Optional. Version being deployed. Defaults to tag.
    version: string
    # Optional. Newline-separated list of deliverables the deployment contains (e.g., microservice name, application name). Defaults to repository name.
    deliverables: string
    # Optional. Newline-separated list of commits SHA shipped as part of the deployment. Defaults to listing commits between the last 2 tags.
    commits: string
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
