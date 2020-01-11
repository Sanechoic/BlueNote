import json
import urllib3
from decimal import Decimal
from datetime import datetime


# AWS
import boto3
from boto3.dynamodb.types import DYNAMODB_CONTEXT

class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal):
            if abs(o) % 1 > 0:
                return float(o)
            else:
                return int(o)
        return super(DecimalEncoder, self).default(o)

def respond(err, res=None):
    '''
    Responds to API gateway request
    '''
    return {
        'statusCode': '400' if err else '200',
        'body': err.message if err else json.dumps(res, cls=DecimalEncoder),
        'headers': {
            'Content-Type': 'application/json',
        },
    }

dynamo = boto3.resource('dynamodb')
def lambda_handler(event, context):
    http = urllib3.PoolManager()
    table = dynamo.Table("tfl_status")

    tfl_url = "https://api.tfl.gov.uk/line/mode/tube/status";
    app_id = "*******";
    app_key = "**************************";

    r = http.request('GET', tfl_url+"?app_id="+app_id+"&app_key="+app_key)

    lines = json.loads(r.data.decode('utf8'))

    for line in lines:
        line['created']=datetime.strftime(datetime.now(), '%Y-%m-%dT%H:%M:%S')
        table.put_item(Item=line)


    return {
        'statusCode': 200,
        'body': r.data.decode('utf')
    }
