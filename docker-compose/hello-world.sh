#!/usr/bin/env bash

if [[ "$1" == "--include-tests" ]]
then
	tests_folder="./tests/"
	tests=`ls $tests_folder`
	for tester in $tests
	do
		eval $tests_folder$tests
	done
else
	echo -e "\n    Use --include-tests to run all scripts in the 'tests' folder    \n"
fi

printf '\e[0;33m %-15s \e[0m Starting...\n' [HelloWorldTests]

function log {
    text="$2"
    if [[ $1 == "OK" ]]
    then
        printf '\e[0;33m %-15s \e[32m SUCCESS:\e[0m %s \n' [HelloWorldTests] "$text"
    else
        printf '\e[0;33m %-15s \e[0;31m FAILED:\e[0m %s \n' [HelloWorldTests] "$text"
    fi
}

# Check if there is at least one device-dynamic
DEVICE_DYNAMIC_ID=$(curl -XGET "https://localhost/api/device-dynamic" -ksS -H 'content-type: application/json' -H 'slipstream-authn-info: super ADMIN' \
| jq -es 'if . == [] then null else .[] | .["deviceDynamics"][0].id end') && \
    log "OK" "device dynamic $DEVICE_DYNAMIC_ID was created successfully" || \
        log "NO" "no device dynamic was added"

# Create SLA template
SLA_TEMPLATE_ID=$(curl -XPOST "https://localhost/api/sla-template" -ksS -H 'content-type: application/json' -H 'slipstream-authn-info: super ADMIN' -d '{
    "name": "compss-hello-world",
    "state": "started",
    "details":{
        "type": "template",
        "name": "compss-hello-world",
        "provider": { "id": "mf2c", "name": "mF2C Platform" },
        "client": { "id": "c02", "name": "A client" },
        "creation": "2018-01-16T17:09:45.01Z",
        "expiration": "2019-01-17T17:09:45.01Z",
        "guarantees": [
            {
                "name": "TestGuarantee",
                "constraint": "execution_time < 10"
            }
        ]
    }
}' | jq -es 'if . == [] then null else .[] | .["resource-id"] end') && \
    log "OK" "service $SLA_TEMPLATE_ID created successfully" || \
        log "NO" "failed to create new service $SLA_TEMPLATE_ID"

# Create hello-world service
SLA_TEMPLATE_ID=`echo $SLA_TEMPLATE_ID | tr -d '"'`
SERVICE_ID=$(curl -XPOST "https://localhost/api/service" -ksS -H 'content-type: application/json' -H 'slipstream-authn-info: super ADMIN' -d '{
    "name": "compss-hello-world",
    "description": "hello world example",
    "exec": "mf2c/compss-test:it2",
    "exec_type": "compss",
    "sla_templates": ["'"$SLA_TEMPLATE_ID"'"],
    "agent_type": "normal",
    "num_agents": 1,
    "cpu_arch": "x86-64",
    "os": "linux",
    "storage_min": 0,
    "req_resource": ["sensor_1"],
    "opt_resource": ["sensor_2"]
}' | jq -es 'if . == [] then null else .[] | .["resource-id"] end') && \
    log "OK" "service $SERVICE_ID created successfully" || \
        log "NO" "failed to create new service $SERVICE_ID"

# Check if analytics return list of agents (!TO BE UPDATED TO PRINT IP ADDRESSES)
(curl -XPOST "http://localhost:46020/mf2c/optimal" -ksS -H 'content-type: application/json' -d '{"name": "compss-hello-world"}' \
| jq -es 'if . == [] then null else .[] | select(.status == 200) end') > /dev/null 2>&1 && \
    log "OK" "list of devices returned successfully" || \
        log "NO" "failed to return list of devices"

# Start hello-world service
SERVICE_ID=`echo $SERVICE_ID | tr -d '"'`
SERVICE_INSTANCE=$(curl -XPOST "http://localhost:46000/api/v2/lm/service" -ksS -H 'content-type: application/json' -d '{
    "service_id": "'"$SERVICE_ID"'"
}' | jq -es 'if . == [] then null else .[] | .service_instance end') && \
    log "OK" "service instance $( jq -r '.id'<<< "${SERVICE_INSTANCE}") launched successfully" || \
        log "NO" "failed to launch service instance $( jq -r '.id'<<< "${SERVICE_INSTANCE}")"