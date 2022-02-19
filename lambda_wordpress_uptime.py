import urllib3


def lambda_handler(event, context):
    http = urllib3.PoolManager()
    request = http.request('GET', 'https://thetwoj.com')
    if request.status != 200:
        raise Exception("Received non-200 status code in response")
    return {
        "success": True
    }
