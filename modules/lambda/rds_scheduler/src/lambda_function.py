import boto3

rds = boto3.client('rds')

def lambda_handler(event, context):
    action = event.get('action')
    required_tags = event.get('tags', {})

    print(f"Action: {action} | Required tags: {required_tags}")

    if action not in ["start", "stop"]:
        print(f"Invalid or missing action: {action}")
        return

    instances = rds.describe_db_instances()['DBInstances']

    for db in instances:
        db_id = db['DBInstanceIdentifier']
        status = db['DBInstanceStatus']
        
        instance_tags = {t['Key']: t['Value'] for t in db.get('TagList', [])}
        
        if all(instance_tags.get(k) == v for k, v in required_tags.items()):
            print(f"Matched RDS: {db_id} (status: {status})")

            if action == "stop" and status == "available":
                print(f"Stopping {db_id}")
                rds.stop_db_instance(DBInstanceIdentifier=db_id)
            elif action == "start" and status == "stopped":
                print(f"Starting {db_id}")
                rds.start_db_instance(DBInstanceIdentifier=db_id)
            else:
                print(f"No action needed for {db_id} (status: {status})")
