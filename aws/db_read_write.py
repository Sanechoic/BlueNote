'''
Database Read-Writer - Last Updated 8/12/19

Description:
    Handles the reading and writing to the AWS lambda tables. It supports GET, POST and PUT requests
    for getting, appending and udpating database items respectively. It cleans the data input (removes empty strings for example)
    and generates fields such as order deadline and invoice line items
'''

# Built In
import json
import decimal
from decimal import Decimal
import random
import string
from datetime import datetime
from datetime import timedelta
import re
import traceback

# AWS
import boto3
from boto3.dynamodb.types import DYNAMODB_CONTEXT


# Set Context for Decimal
# Inhibit Inexact Exceptions
DYNAMODB_CONTEXT.traps[decimal.Inexact] = 0
# Inhibit Rounded Exceptions
DYNAMODB_CONTEXT.traps[decimal.Rounded] = 0

hubs_skip = ['lineItems', 'deadline', 'str_to_decimal', 'order_folder']

class DecimalEncoder(json.JSONEncoder):
    '''
    Encodes decimals for json
    '''
    def default(self, o):
        if isinstance(o, Decimal):
            return float(o)
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


def remove_invalid_from_dict(d, invalid=['']):
    if type(d) is dict:
        return dict((k, remove_invalid_from_dict(v)) for k, v in d.items() if v not in invalid and remove_invalid_from_dict(v) not in invalid)
    elif type(d) is list:
        return [remove_invalid_from_dict(v) for v in d if v not in invalid and remove_invalid_from_dict(v) not in invalid]
    else:
        return d


print('Loading function')
dynamo = boto3.resource('dynamodb')

def lambda_handler(event, context):
    '''
    Demonstrates a simple HTTP endpoint using API Gateway. You have full
    access to the request and response payload, including headers and
    status code.

    To scan a DynamoDB table, make a GET request with the TableName as a
    query string parameter. To put, update, or delete an item, make a POST,
    PUT, or DELETE request respectively, passing in the payload to the
    DynamoDB API as a JSON body.
    '''
    print(event)

    table = dynamo.Table(event['queryStringParameters']['TableName'])

    operations = {
        'DELETE': table.delete_item,
           'GET': table.get_item,
          'POST': table.put_item,
           'PUT': table.update_item,
    }


    operation = event['httpMethod']
    if operation in operations:

        # Adding New Item to dabatabse
        if operation == 'POST':
            item = dict(json.loads(event['body'], parse_float=Decimal))
            # remove empty string and other invalid entries from item
            item = remove_invalid_from_dict(item)
            print(item)
            return respond(None, operations[operation](Item=item))

        # Getting or deleting Item from dabatabse
        else:
            print('Key: {}'.format(key))
            return respond(None, operations[operation](Key=key))

    else:
        return respond(ValueError('Unsupported method "{}"'.format(operation)))
