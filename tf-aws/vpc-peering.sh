#!/bin/bash

SCRIPT_NAME=$(basename "$0" | cut -d. -f1)
LOGFILE="${SCRIPT_NAME}.log"

cat /dev/null > "$LOGFILE"

# Function to log commands and their outputs
log_cmd() {
    echo "Command: $@" >> "$LOGFILE"
    result=$("$@" 2>&1)
    echo "Output: $result" >> "$LOGFILE"
    echo "$result"
}

get_route_table_id() {
    local cluster_name=$1
    local region=$2
    
    log_cmd aws ec2 describe-route-tables \
        --region $region \
        --filters "Name=tag:Name,Values=$cluster_name" \
        --query 'RouteTables[0].RouteTableId' \
        --output text
}

# Check for arguments
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]; then
    echo "Error: Missing arguments. Usage: $0 <Action> <Local VPC Name> <Local Region> <Remote VPC Name> <Remote Region> [Local Route CIDR] [Remote Route CIDR]" | tee -a "$LOGFILE"
    exit 1
fi

# Inputs
ACTION="$1"
LOCAL_VPC_NAME="$2"
LOCAL_REGION="$3"
REMOTE_VPC_NAME="$4"
REMOTE_REGION="$5"
LOCAL_ROUTE_CIDR="$6"
REMOTE_ROUTE_CIDR="$7"

# Fetch VPC IDs using VPC names
LOCAL_VPC_ID=$(log_cmd aws ec2 describe-vpcs --region "$LOCAL_REGION" --filters "Name=tag:Name,Values=$LOCAL_VPC_NAME" --query "Vpcs[0].VpcId" --output text)
REMOTE_VPC_ID=$(log_cmd aws ec2 describe-vpcs --region "$REMOTE_REGION" --filters "Name=tag:Name,Values=$REMOTE_VPC_NAME" --query "Vpcs[0].VpcId" --output text)

if [ "$LOCAL_VPC_ID" == "None" ] || [ -z "$LOCAL_VPC_ID" ]; then
    echo "Error: Local VPC with name $LOCAL_VPC_NAME not found." | tee -a "$LOGFILE"
    exit 1
fi

if [ "$REMOTE_VPC_ID" == "None" ] || [ -z "$REMOTE_VPC_ID" ]; then
    echo "Error: Remote VPC with name $REMOTE_VPC_NAME not found." | tee -a "$LOGFILE"
    exit 1
fi

LOCAL_ROUTE_TABLE_ID=$(get_route_table_id "$LOCAL_VPC_NAME" "$LOCAL_REGION")
REMOTE_ROUTE_TABLE_ID=$(get_route_table_id "$REMOTE_VPC_NAME" "$REMOTE_REGION")

delete_peering() {
  # Delete routes in local VPC's route table
  log_cmd aws ec2 delete-route --route-table-id "$LOCAL_ROUTE_TABLE_ID" --destination-cidr-block "$REMOTE_ROUTE_CIDR" --region "$LOCAL_REGION"

  # Delete routes in remote VPC's route table
  log_cmd aws ec2 delete-route --route-table-id "$REMOTE_ROUTE_TABLE_ID" --destination-cidr-block "$LOCAL_ROUTE_CIDR" --region "$REMOTE_REGION"

  # Delete peering connections for Local VPC
  PEERING_IDS_LOCAL=$(log_cmd aws ec2 describe-vpc-peering-connections --region "$LOCAL_REGION" --filters "Name=requester-vpc-info.vpc-id,Values=$LOCAL_VPC_ID" --query "VpcPeeringConnections[].VpcPeeringConnectionId" --output text)
  for ID in $PEERING_IDS_LOCAL; do
      log_cmd aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id "$ID" --region "$LOCAL_REGION"
  done

  # Delete peering connections for Remote VPC
  PEERING_IDS_REMOTE=$(log_cmd aws ec2 describe-vpc-peering-connections --region "$REMOTE_REGION" --filters "Name=requester-vpc-info.vpc-id,Values=$REMOTE_VPC_ID" --query "VpcPeeringConnections[].VpcPeeringConnectionId" --output text)
  for ID in $PEERING_IDS_REMOTE; do
      log_cmd aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id "$ID" --region "$REMOTE_REGION"
  done
}

create_peering() {
  # Create new VPC peering connection with Name tag set to "LocalVPCName-To-RemoteVPCName"
  PEERING_NAME="${LOCAL_VPC_NAME}-To-${REMOTE_VPC_NAME}"
  NEW_PEERING_ID=$(log_cmd aws ec2 create-vpc-peering-connection \
    --vpc-id "$LOCAL_VPC_ID" \
    --peer-vpc-id "$REMOTE_VPC_ID" \
    --peer-region "$REMOTE_REGION" \
    --region "$LOCAL_REGION" \
    --tag-specifications "ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=${PEERING_NAME}}]" \
    --query "VpcPeeringConnection.VpcPeeringConnectionId" \
    --output text)

  # Pause until VPC peering connection exists
  log_cmd aws ec2 wait vpc-peering-connection-exists --vpc-peering-connection-ids "$NEW_PEERING_ID"

  sleep 10

  # Accept the peering connection in Remote Region
  log_cmd aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id "$NEW_PEERING_ID" --region "$REMOTE_REGION"

  sleep 10

  # Add routes in local VPC's route table
  log_cmd aws ec2 create-route --route-table-id "$LOCAL_ROUTE_TABLE_ID" --destination-cidr-block "$REMOTE_ROUTE_CIDR" --vpc-peering-connection-id "$NEW_PEERING_ID" --region "$LOCAL_REGION"

  # Add routes in remote VPC's route table
  log_cmd aws ec2 create-route --route-table-id "$REMOTE_ROUTE_TABLE_ID" --destination-cidr-block "$LOCAL_ROUTE_CIDR" --vpc-peering-connection-id "$NEW_PEERING_ID" --region "$REMOTE_REGION"
}

case "$ACTION" in
  "delete")
    delete_peering
    ;;

  "create")
    create_peering
    ;;

  "delete-and-create")
    delete_peering
    create_peering
    ;;

  *)
    echo "Invalid action. Please choose either 'delete', 'create', or 'delete-and-create'." | tee -a "$LOGFILE"
    exit 1
    ;;
esac

echo "Operation '$ACTION' completed." | tee -a "$LOGFILE"
 
