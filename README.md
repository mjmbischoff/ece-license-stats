# Setup

## 1. Setup data stream

To setup the data stream we just need to setup the templates and ilm policy, the data stream itself is auto created when we receive the first document.

See the following four requests in `setup.kibana-devtools` file:
```kibana-devtools
PUT _ilm/policy/ece-info
PUT _component_template/ece-info-mappings
PUT _component_template/ece-info-settings
PUT _index_template/ece-info-index-template
```
These should be run against the cluster where we collect data (/dashboards)

## 2. Setup ingest pipelines

See the following two requests in `setup.kibana-devtools` file:
```kibana-devtools
PUT _ingest/pipeline/collect-ece-license-info
PUT deploymentname-usage_type
PUT _enrich/policy/deploymentname-usage_type-policy
POST /_enrich/policy/deploymentname-usage_type-policy/_execute
PUT deploymentname-category
POST /deploymentname-category/_doc/logging-and-metrics
POST /deploymentname-category/_doc/admin-console-elasticsearch
POST /deploymentname-category/_doc/security-cluster
PUT _enrich/policy/deploymentname-category-policy
POST _enrich/policy/deploymentname-category-policy/_execute
PUT _ingest/pipeline/collect-ece-deployments
```
Both of these should be run against the cluster where we collect data (/dashboards)

## 3. Generate API key for target elasticsearch cluster to be used by scripts

See the following request in `setup.kibana-devtools` file:
```kibana-devtools
POST /_security/api_key
```
When run the result should be something like this:
```json
{
  "id": "kREOVoIB2NcjdKaTfYzw",
  "name": "ece-license-information-api-key",
  "api_key": "el3ZHXIBSPS39fT-Xh1o7A",
  "encoded": "a1JFT1ZvSUIyTmNqZEthVGZZenc6ZWwzWkhYSUJTUFMzOWZULVhoMW83QQ=="
}
```
where `"encoded": "a1JFT1ZvSUIyTmNqZEthVGZZenc6ZWwzWkhYSUJTUFMzOWZULVhoMW83QQ=="` is the part we want to note down for later use.


## 4. Install cron jobs

For each ECE installation you should set up the cron jobs(or your other favorite way of running periodic tasks):

### install dependencies

the scripts rely on `curl`
> curl is a tool to transfer data from or to a server

the scripts rely on `date`
> date - print or set the system date and time

the scripts rely on `jq` 
> jq is a tool for processing JSON inputs, applying the given filter to
its JSON text inputs and producing the filter's results as JSON on
standard output.

### add scripts in a location and make them executable

`chmod +x *`

### add the commands to execute

```bash
env CLUSTER_NAME="<unique identifier>" ECE_API_KEY="<your API key>" TARGET_CLUSTER="< base url >" ENCODED_API_KEY="<ES API KEY>" /<abs path>/collect-ece-installed-licenses.sh
```

```bash
env CLUSTER_NAME="<unique identifier>" ECE_API_KEY="<your API key>" TARGET_CLUSTER="< base url >" ENCODED_API_KEY="<ES API KEY>" /<abs path>/collect-ece-deployments.sh
```

The scripts can be run by a non-privileged user as only external calls are made and data is only kept in memory

#### Environment variables used by scripts:

| ENV var                | description       |
|------------------------|-------------------|
| ECE_API_KEY            | ECE API key, the api key created for an (non-root) ECE admin console user PLATFORM VIEWER permission |
| ECE_HOSTNAME           | defaults to `localhost` |
| ECE_PORT               | defaults to `12443` |
| TARGET_CLUSTER         | protocol://host[:port] of custer we want to store data and against which we ran the setup requests | 
| ENCODED_API_KEY        | your API key as returned by the `POST /_security/api_key` request earlier in step 3 |
| ADDITIONAL_CURL_FLAGS  | arguments / flags passed to CURL for example `ADDITIONAL_CURL_FLAGS="--insecure"` if skipping adding cert to trust store

## 5. install dashboards

import saved objects, goto kibana and use `ece-info.ndjson`

# Design

## collect and push

Data is retieved from the ECE installation using the ECE api https://www.elastic.co/guide/en/cloud-enterprise/current/ece-api-reference.html and pushed to an elasticsearch instance using the index api https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-index_.html Although these are pretty stable, it might be that the scripts need to be adapted to new versions. 

---
**_Please note:_** 

As long as the structure of the outputted documents are the same you can run different versions of the script for different ECE installations(running different versions)

---

## processing of documents centralized
We transform the documents in ingest pipelines and not in the bash script to ease updating later as we likely only need to make changes on the receiving cluster.

---
**_Please note:_** 

The different components(scripts, index pipelines, template, mappings, index name) aren't currently versioned should you want to run a mixed version environment it might be useful to introduce this. 

### Identifying usage_type and category

To identify a deployment's category or usage type we use the enrich processor where we do a lookup based on name. This could be adapted to use the id instead if id is not sufficiently unique. This technique can also be used to attach other metadata like the team owning the deployment or customer

```json
    {
      "enrich": {
        "description": "Add 'category' data based on deployment name",
        "policy_name": "deploymentname-category-policy",
        "field": "name",
        "target_field": "found-category",
        "max_matches": "1"
      }
    },
    {
      "rename": {
        "field": "found-category.category",
        "target_field": "category",
        "on_failure": [
          {
            "set": {
              "field": "category",
              "value": "unindentified",
              "override": false
            }
          }
        ]
      }
    }
```

to add an entry to match on, run the following command:
```
POST /deploymentname-category/_doc/logging-and-metrics
{
  "name": "logging-and-metrics",
  "category": "system"
}
POST /_enrich/policy/deploymentname-category-policy/_execute
```
---

# Uninstall

Run the following commands in Kibana dev tools:

```kibana-devtools
DELETE _data_stream/ece-info
DELETE _index_template/ece-info-index-template
DELETE _component_template/ece-info-settings
DELETE _component_template/ece-info-mappings
DELETE _ilm/policy/ece-info
DELETE _security/api_key
{
  "name": "ece-license-information-api-key"
}
DELETE _ingest/pipeline/collect-ece-license-info
DELETE _ingest/pipeline/collect-ece-deployments
POST _transform/ece-info-deployments-latest-status/_stop
DELETE _transform/ece-info-deployments-latest-status
```