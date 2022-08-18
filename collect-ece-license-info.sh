#! /bin/bash
#set -o xtrace
JSON=$(curl \
    ${ADDITIONAL_CURL_FLAGS:-} \
    -XGET https://${ECE_HOSTNAME:-localhost}:${ECE_PORT:-12443}/api/v1/platform/license \
    -H "Authorization: ApiKey ${ECE_API_KEY}"
)

if [ ${JSON: -1} == "}" ]; then
    JSON="${JSON::-1}, \"cluster_name\":\"${CLUSTER_NAME:-unknown}\", \"@timestamp\":\"$(date +%s%3N)\" }"

    JSON=${JSON//$'\n'/}

    RESPONSE=$(curl \
        ${ADDITIONAL_CURL_FLAGS:-} \
        -XPOST "${TARGET_CLUSTER}/${TARGET_INDEX:-ece-info}/_doc?pipeline=collect-ece-license-info" \
        -H "kbn-xsrf: reporting" \
        -H "Content-Type: application/json" \
        -H "Authorization: ApiKey ${ENCODED_API_KEY}" \
        -d "$JSON"
    )
fi
