#!/bin/bash

# Detect if the Akamai forwarders are failing.  
# Disable Infoblox forwarding if necessary.

# Define Infoblox WAPI
IB_SERVER="infoblox-grid-master-ip"
IB_USERNAME="api-username"
IB_PASSWORD="api-password"
IB_VIEWS=("Guest" "Internal")

NOTIFY="admin-email"

# Define the servers we will test
AKAMAI=(akamai_ip1 akamai_ip2)
OTHER=(8.8.8.8 9.9.9.9 1.1.1.1)

# What we will query for
TEST="google.com"

function restart_dns() {
    # Restart Infoblox DNS if needed
    echo "Restarting Infoblox DNS"

    # Get the grid object reference
    PARMS="-d _return_fields%2B=restart_status"
    grid=$(curl -s -k1 -u ${IB_USERNAME}:${IB_PASSWORD} -X GET https://${IB_SERVER}/wapi/v2.10.5/grid ${PARMS})
    grid_ref=$(echo ${grid} | jq .[]._ref | sed 's/"//g')
    #echo $grid

    # Restart DNS services if necessary
    RESTART=$(curl -s -k1 -u ${IB_USERNAME}:${IB_PASSWORD} -H 'content-type: application/json' -X POST https://${IB_SERVER}/wapi/v2.10.5/${grid_ref}?_function=restartservices -d '{"ser
vices": [ "DNS" ], "mode": "GROUPED", "restart_option": "RESTART_IF_NEEDED"}')
    echo $RESTART

}

# Count query success
AKAMAI_OK=0
OTHER_OK=0
BAD_FORWARDERS=0

DATE=$(date)
echo "Starting Akamai forwarding tests at ${DATE}"
echo "Test query: ${TEST}"

# DNS query loop to get status of the servers
counter=0
while [ $counter -lt 5 ]
do
    echo "---"
    echo "Starting loop $counter"

    # Check Akamai first
    for server in "${AKAMAI[@]}"
    do
        resolvedIP=$(dig @${server} +short -t A ${TEST})

        if [[ -z "${resolvedIP}" ]];
        then
            echo "${server} lookup failed"
        else
            ((AKAMAI_OK++))
            echo "${server} lookup success"
        fi
    done

    # Check other public resolvers second
    for server in "${OTHER[@]}"
    do
        resolvedIP=$(dig @${server} +short -t A ${TEST})

        if [[ -z "${resolvedIP}" ]];
        then
            echo "${server} lookup failed"
        else
            ((OTHER_OK++))
            echo "${server} lookup success"
        fi
    done

    # Find when Akamai completely failed but the others did not
    if [ $AKAMAI_OK -eq 0 ] && [ $OTHER_OK -gt 0 ];
    then
        echo "!!! Akamai is not responding, but other things are. !!!"
        ((BAD_FORWARDERS++))
    fi

    sleep 1
    ((counter++))
done

echo "---"
echo "Akamai forwarding was bad ${BAD_FORWARDERS} out of ${counter} loops"
echo "==="

CHANGES=()
for ib_view in "${IB_VIEWS[@]}"
do
    echo "Checking if view ${ib_view} needs to be updated"

    # Check the state of Infoblox forwarding
    PARMS="-d name=${ib_view} -d _return_fields%2B=forwarders,use_forwarders"
    view=$(curl -s -k1 -u ${IB_USERNAME}:${IB_PASSWORD} -X GET https://${IB_SERVER}/wapi/v2.10.5/view ${PARMS})
    #echo $view
    view_ref=$(echo ${view} | jq .[]._ref | sed 's/"//g')
    view_name=$(echo ${view} | jq .[].name | sed 's/"//g')
    view_forwarders=$(echo ${view} | jq .[].forwarders)
    view_use_forwarders=$(echo ${view} | jq .[].use_forwarders)

    echo "$view_name is set with use_forwarders = $view_use_forwarders"

    if [ $BAD_FORWARDERS -eq 0 ] && [ $view_use_forwarders = "false" ]
    then
        # This is when Akamai is working and Infoblox is not trying to use it
        echo "View needs Akamai forwarding enabled"

        # Update the forwarding option
        PARMS="-d use_forwarders=true"
        RESULT=$(curl -s -k1 -u ${IB_USERNAME}:${IB_PASSWORD} -X PUT https://${IB_SERVER}/wapi/v2.10.5/${view_ref} ${PARMS})
        echo $RESULT

        echo "Forwarding was enabled in the ${view_name} view."
        CHANGES+=("Forwarding was enabled in the ${view_name} view.")

    elif [ $BAD_FORWARDERS -gt 1 ] && [ $view_use_forwarders = "true" ]
    then
        # This is when Akamai is broken and Infoblox is still trying to use it
        echo "View needs Akamai forwarding disabled"

        # Update the forwarding option
        PARMS="-d use_forwarders=false"
        RESULT=$(curl -s -k1 -u ${IB_USERNAME}:${IB_PASSWORD} -X PUT https://${IB_SERVER}/wapi/v2.10.5/${view_ref} ${PARMS})
        echo $RESULT

        echo "Forwarding was disabled in the ${view_name} view."
        CHANGES+=("Forwarding was disabled in the ${view_name} view.")

    else
        # No changes are needed
        echo "No updates are necessary in the View ${ib_view}"

    fi

done

# Check if we made any changes
if (( ${#CHANGES[@]} > 0 ))
then
    echo "==="
    echo "Infoblox forwarding was updated on ${IB_SERVER}"

    TEXT="Infoblox forwarding was updated on ${IB_SERVER} at ${DATE}."
    TEXT="${TEXT}  Akamai was bad ${BAD_FORWARDERS} out of ${counter} loops."
    for LINE in "${CHANGES[@]}"
    do
        TEXT="${TEXT}  ${LINE}"
    done
    
    restart_dns
    TEXT="${TEXT}  DNS was restarted."

    mail -s "Akamai Forwarding Updated" ${NOTIFY} <<< "${TEXT}"

else
    echo "==="
    echo "Infoblox forwarding was not updated on ${IB_SERVER}"

fi

echo ""
