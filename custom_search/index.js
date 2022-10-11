// Lambda function code
import { URLSearchParams } from 'url'
import fetch from 'node-fetch'

const handler = async (event) => {
  console.log('Event: ', event);
  const baseUrl = 'https://www.googleapis.com/customsearch/v1'

  let query = ''
  if (event.queryStringParameters && event.queryStringParameters['q']) {
    query = event.queryStringParameters['q']
  }
  
  let start = 1
  if (event.queryStringParameters && event.queryStringParameters['start']) {
    start = event.queryStringParameters['start']
  }

  let num = 10
  if (event.queryStringParameters && event.queryStringParameters['num']) {
    num = event.queryStringParameters['num']
  }

  const key = process.env['CUSTOM_SEARCH_KEY']
  const cx = process.env['CUSTOM_SEARCH_CX']

  const params = new URLSearchParams({
    q: query,
    start,
    num,
    key,
    cx,
  })

  const response = await fetch(baseUrl + '?' + params.toString(), {
    method: 'GET',
  })
  .then((response) => {
    return response.json();
  })
  console.log(response)

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(response),
  }
}

export { handler }
