#!/bin/bash -l

# includes
. /helpers.sh

git config --global --add safe.directory "${GITHUB_WORKSPACE}"

ECHOES_API_ENDPOINT="https://api.echoeshq.com/v1/signals/deployments"

while getopts ":t:v:d:c:u:s:i:" opt; do
    case $opt in
        t) action_type=$(trim "${OPTARG}")
        ;;
        v) version=$(trim "${OPTARG}")
        ;;
        d)
        mapfile -t deliverables < <(trim "${OPTARG}")
        ;;
        c)
        mapfile -t commits < <(trim "${OPTARG}")
        ;;
        u) url=$(trim "${OPTARG}")
        ;;
        s) status=$(trim "${OPTARG}")
        ;;
        i) deployment_id=$(trim "${OPTARG}")
        ;;
        \?) echo "Invalid option -${OPTARG}" >&2
        exit 1
        ;;
    esac

    case $OPTARG in
        -*) echo "Option $opt needs a valid argument"
        exit 1
        ;;
    esac
done

# Makes sure the API KEY is provided
if [ -z "${ECHOES_API_KEY}" ]
then
    echo "No ECHOES_API_KEY provided! Please visit: https://docs.echoeshq.com/api-authentication#ZB9nc"
    exit 1
fi

# Is the action used to post a deployment status?
if [ "${action_type}" == "post-status" ]
then
    if [ -z "${status}" ] || [ -z "${deployment_id}" ]
    then
        echo "A status and a deployment ID are required. https://echoeshq.stoplight.io/docs/public-api/9vr19ihfs1pka-post-deployment-status"
        exit 1
    fi

    response=$(curl --silent --show-error --fail-with-body --location "${ECHOES_API_ENDPOINT}/${deployment_id}/status" \
    --header 'Content-Type: application/json' \
    --header 'Authorization: Bearer '"${ECHOES_API_KEY}"'' \
    --data-raw '{
       "status": "'"${status}"'"
    }')

    if [[ "${response}" != "" ]]
    then
        echo "${response}"
        if [[ "$(echo "${response}" | jq .status)" -ge 400 ]]
        then
            exit 1
        fi
    fi

    exit 0
fi

# If no deliverables provided look up for the GITHUB_REPOSITORY.
# If the value could be empty.
if [ -z "${deliverables[0]}" ] || [ "$(arraylength "${deliverables[@]}")" -eq 0 ]
then
    echo "No deliverables list provided, defaults to \$GITHUB_REPOSITORY."

    if [ -z "${GITHUB_REPOSITORY}" ]
    then
        echo "\$GITHUB_REPOSITORY is missing. Please make sure to have used the actions/checkout or provide a deliverables list."
        exit 1
    fi

    # Keep the repository name only as deliverable value
    deliverables=( "${GITHUB_REPOSITORY//${GITHUB_REPOSITORY_OWNER}\//}" )
fi

# If no commits provided look up for tags.
# If no tags are found, look up for the commit SHA triggering the workflow (GITHUB_SHA).
if [ -z "${commits[0]}" ] || [ "$(arraylength "${commits[@]}")" -eq 0 ]
then
    # No commits list provided therefore look for tags
    echo "Looking for commits via tags..."

    latestTags=$(git for-each-ref refs/tags --sort=-committerdate --format='%(refname:short)' --count=2 --merged)

    if [ -z "${latestTags}" ]
    then
        echo "No tags were found, therefore looking for \$GITHUB_SHA"
        if [ -z "${GITHUB_SHA}" ]
        then
            echo "No tags were found, nor \$GITHUB_SHA therefore no deployment can be submitted."
            echo "Please provide a commits list or make sure to have used the actions/checkout beforehand."
            exit 1
        else
            commits=("${GITHUB_SHA}")
        fi
    else
        mapfile -t tags <<< "$latestTags"
        numberOfTags=$(arraylength "${tags[@]}")

        if [ "${numberOfTags}" -gt 0 ]
        then
            if [ "${numberOfTags}" -lt 2 ]
            then
                tag=${tags[0]}

                echo "Extract commits from ${tag}"

                mapfile -t commits < <(git log --pretty=format:%H "${tag}")
            else
                tag=${tags[0]}
                prev_tag=${tags[1]}

                echo "Extract commits from ${prev_tag} to ${tag}"

                mapfile -t commits < <(git log --pretty=format:%H "${prev_tag}".."${tag}")
            fi

            if [ -z "${url}" ]
            then
                url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/releases/tag/${tag}"
            fi
        fi
    fi
fi


deliverablesJSON=$(jq --compact-output --null-input '$ARGS.positional' --args "${deliverables[@]}")
commitsJSON=$(jq --compact-output --null-input '$ARGS.positional' --args "${commits[@]}")

response=$(curl --silent --show-error --fail-with-body --location "${ECHOES_API_ENDPOINT}" \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer '"${ECHOES_API_KEY}"'' \
--data-raw '{
    "version": "'"${version}"'",
    "commits": '"${commitsJSON}"',
    "deliverables": '"${deliverablesJSON}"',
    "url": "'"${url}"'"
}')

# Display response body
echo "${response}"

if [[ "${response}" != "" ]]
then
    if [[ "$(echo "${response}" | jq .status)" -ge 400 ]]
    then
        exit 1
    fi

    deployment_id=$(echo "${response}" | jq .id)
    echo "deployment_id=${deployment_id}" >> "${GITHUB_OUTPUT}"
fi
