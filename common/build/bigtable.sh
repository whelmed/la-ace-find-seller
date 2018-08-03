#!/bin/bash

# Import the settings from the common settings file
source ../project_settings.sh


# These are the settings for the actual table and table family
declare -a TABLE_FAMILIES=("item" "buyer" "seller")


# Is this a production instance or development. Prod will be more expensive and ready for production workloads. 
# Development is for non-production workloads.
BIGTABLE_INSTANCE_TYPE="development"
# This can be set to hdd or ssd. However, only use this for production.
BIGTABLE_CLUSTER_STORAGE_TYPE="hdd"
# You don't want to use the cluster-storage-type for dev environments. 
BIGTABLE_CLUSTER_STORAGE_TYPE_FLAG="--cluster-storage-type="
# This will combine the flag and the value, but only for production workloads. As determined by the BIGTABLE_INSTANCE_TYPE variable.
BIGTABLE_CLUSTER_STORAGE_TYPE_FLAG_VALUE=""

# How many nodes should we use? For production, use at least 3. Doesn't matter for development
CLUSTER_NUM_NODES="3"
# You don't want to use the cluster-num-nodes for dev environments. 
BIGTABLE_CLUSTER_NUM_NODES_FLAG="--cluster-num-nodes="
# This will combine the flag and the value, but only for production workloads. As determined by the BIGTABLE_INSTANCE_TYPE variable.
BIGTABLE_CLUSTER_NUM_NODES_FLAG_VALUE=""
# If this is a production environment, combine the flag and the value for storage type.

if [[ $BIGTABLE_INSTANCE_TYPE == "production" ]]; then
    BIGTABLE_CLUSTER_STORAGE_TYPE_FLAG_VALUE="$BIGTABLE_CLUSTER_STORAGE_TYPE_FLAG$BIGTABLE_CLUSTER_STORAGE_TYPE"        
    BIGTABLE_CLUSTER_NUM_NODES_FLAG_VALUE="$BIGTABLE_CLUSTER_NUM_NODES_FLAG$CLUSTER_NUM_NODES"
fi

# This could also be done with the "cbt" command. HOWEVER...this is more explicit in the flag names, so that's what we'll use.
gcloud beta bigtable instances create $BIGTABLE_INSTANCE_ID \
    --project=$PROJECT_NAME \
    --cluster=$BIGTABLE_CLUSTER_ID \
    --cluster-zone=$PROJECT_ZONE \
    --display-name=$BIGTABLE_DISPLAY_NAME \
    $BIGTABLE_CLUSTER_NUM_NODES_FLAG_VALUE \
    $BIGTABLE_CLUSTER_STORAGE_TYPE_FLAG_VALUE \
    --instance-type=$BIGTABLE_INSTANCE_TYPE 


if [ -z $(which cbt) ]; then
    echo "You must install cbt. If you have the cloud SDK installed then run the following:"
    echo "gcloud components update"
    echo "gcloud components install cbt"
    echo "See https://cloud.google.com/bigtable/docs/cbt-overview for more details."

    exit 1
fi

# Create the table
cbt -instance $BIGTABLE_INSTANCE_ID -project $PROJECT_NAME createtable $BIGTABLE_TABLE_ID

# Loop over the family names and create them.
for i in "${TABLE_FAMILIES[@]}"
do
   cbt -instance $BIGTABLE_INSTANCE_ID -project $PROJECT_NAME createfamily $BIGTABLE_TABLE_ID $i
done

cat > bigquery_table_def.json << EOL
{
    "sourceFormat": "BIGTABLE",
    "sourceUris": [
        "https://googleapis.com/bigtable/projects/$PROJECT_NAME/instances/$BIGTABLE_INSTANCE_ID/tables/$BIGTABLE_TABLE_ID"
    ],
    "bigtableOptions": {
        "readRowkeyAsString": "true",
        "columnFamilies" : [
            {
                "familyId": "item",
                "onlyReadLatest": "true",
                "type": "STRING"
            },
            {
                "familyId": "buyer",
                "onlyReadLatest": "true",
                "type": "STRING"
            },
            {
                "familyId": "seller",
                "onlyReadLatest": "true",
                "type": "STRING"
            }
        ]
    }
}
EOL


