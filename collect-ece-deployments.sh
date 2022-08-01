#! /bin/bash
#set -o xtrace
DEPLOYMENTS_LIST_JSON=$(curl \
    ${ADDITIONAL_CURL_FLAGS:-} \
    -XGET https://${ECE_HOSTNAME:-localhost}:${ECE_PORT:-12443}/api/v1/deployments \
    -H "Authorization: ApiKey ${ECE_API_KEY}"
)

DEPLOYMENT_IDS=$(echo ${DEPLOYMENTS_LIST_JSON} | jq -r '.deployments[].id' )

while read -r line; do
    JSON=$(curl \
        ${ADDITIONAL_CURL_FLAGS:-} \
        -XGET https://${ECE_HOSTNAME:-localhost}:${ECE_PORT:-12443}/api/v1/deployments/${line} \
        -H "Authorization: ApiKey ${ECE_API_KEY}"
    )

    if [ ${JSON: -1} == "}" ]; then
        JSON="${JSON::-1}, \"cluster_name\":\"${CLUSTER_NAME:-unknown}\", \"@timestamp\":\"$(date +%s%3N)\" }"

        JSON=${JSON//$'\n'/}

        RESPONSE=$(curl \
            -XPOST "${TARGET_CLUSTER}/${TARGET_INDEX:-ece-info}/_doc?pipeline=collect-ece-deployments" \
            -H "kbn-xsrf: reporting" \
            -H "Content-Type: application/json" \
            -H "Authorization: ApiKey ${ENCODED_API_KEY}" \
            -d "$JSON"
        )
    fi
done <<< "$DEPLOYMENT_IDS"
