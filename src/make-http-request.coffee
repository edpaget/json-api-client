cachedGets = {}

makeHTTPRequest = (method, url, data, headers, modify) ->
  originalArguments = Array::slice.call arguments # In case we need to retry

  method = method.toUpperCase()

  if method is 'GET'
    if data? and Object.keys(data).length isnt 0
      url += if url.indexOf('?') is -1
        '?'
      else
        '&'
      url += ([key, value].join '=' for key, value of data).join '&'
      data = null

    promise = cachedGets[url]

  promise ?= new Promise (resolve, reject) ->
    # console.log "Opening #{method} request for #{url}", data

    request = new XMLHttpRequest
    request.open method, encodeURI url

    request.withCredentials = true

    if headers?
      for header, value of headers when value?
        request.setRequestHeader header, value

    if modify?
      modify request

    request.onreadystatechange = (e) ->
      if request.readyState is request.DONE
        if method is 'GET'
          delete cachedGets[url]

        if 200 <= request.status < 300
          resolve request
        else if request.status is 408 # Try again
          makeHTTPRequest.apply null, originalArguments
            .then resolve
            .catch reject
        else
          reject request

    if data? and headers?['Content-Type']?.indexOf('json') isnt -1
      data = JSON.stringify data

    request.send data

  if method is 'GET'
    cachedGets[url] = promise

  promise

module.exports = makeHTTPRequest
