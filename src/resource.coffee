print = require './print'
Emitter = require './emitter'
mergeInto = require './merge-into'

module.exports = class Resource extends Emitter
  _type: null # The resource type object

  _readOnlyKeys: ['id', 'type', 'href', 'created_at', 'updated_at']

  _changedKeys: null # Dirty keys

  constructor: (config...) ->
    super
    @_changedKeys = []
    mergeInto this, config... if config?
    @emit 'create'
    print.info "Constructed a resource: #{@_type.name} #{@id}", this

  # Get a promise for an attribute referring to (an)other resource(s).
  attr: (attribute) ->
    print.info 'Getting link:', attribute
    if attribute of this
      print.warn "No need to access a non-linked attribute via attr: #{attribute}", this
      Promise.resolve @[attribute]
    else if @links? and attribute of @links
      print.log 'Link of resource'
      @_getLink attribute, @links[attribute]
    else if attribute of @_type.links
      print.log 'Link of type'
      @_getLink attribute, @_type.links[attribute]
    else
      print.error 'Not a link at all'
      Promise.reject new Error "No attribute #{attribute} of #{@_type.name} resource"

  _getLink: (name, link) ->
    if typeof link is 'string' or Array.isArray link
      print.log 'Linked by ID(s)'
      ids = link
      {href, type} = @_type.links[name]

      if href?
        context = {}
        context[@_type.name] = this
        href = @applyHREF href, context
        @_type.apiClient.get href

      else if type?
        type = @_type.apiClient.types[type]
        type.get ids

    else if link?
      print.log 'Linked by collection object', link
      # It's a collection object.
      {href, ids, type} = link

      if href?
        context = {}
        context[@_type.name] = this
        print.warn 'HREF', href
        href = @applyHREF href, context
        @_type.apiClient.get href

      else if type? and ids?
        type = @_type.apiClient.types[type]
        type.get ids

    else
      print.log 'Linked, but blank'
      # It exists, but it's blank.
      Promise.resolve null

  # Turn a JSON-API "href" template into a usable URL.
  PLACEHOLDERS_PATTERN: /{(.+?)}/g
  applyHREF: (href, context) ->
    href.replace @PLACEHOLDERS_PATTERN, (_, path) ->
      segments = path.split '.'
      print.warn 'Segments', segments

      value = context
      until segments.length is 0
        segment = segments.shift()
        value = value[segment] ? value.links?[segment]

      print.warn 'Value', value

      if Array.isArray value
        value = value.join ','

      unless typeof value is 'string'
        throw new Error "Value for '#{path}' in '#{href}' should be a string."

      value

  update: (changeSet = {}) ->
    @emit 'will-change'
    actualChanges = 0

    for key, value of changeSet when @[key] isnt value
      @[key] = value
      unless key in @_changedKeys
        @_changedKeys.push key
      actualChanges += 1

    unless actualChanges is 0
      @emit 'change'

  save: ->
    @emit 'will-save'

    payload = {}
    payload[@_type.name] = @getChangesSinceSave()

    save = if @id
      @_type.apiClient.put @getURL(), payload
    else
      @_type.apiClient.post @_type.getURL(), payload

    save.then (results) =>
      @update results
      @_changedKeys.splice 0
      @emit 'save'
      results

  getChangesSinceSave: ->
    changes = {}
    for key in @_changedKeys
      changes[key] = @[key]
    changes

  delete: ->
    @emit 'will-delete'
    deletion = if @id
      @_type.apiClient.delete @getURL()
    else
      Promise.resolve()

    deletion.then =>
      @emit 'delete'

  matchesQuery: (query) ->
    matches = true
    for param, value of query
      if @[param] isnt value
        matches = false
        break
    matches

  emit: (signal, payload) ->
    super
    @_type._handleResourceEmission this, arguments...

  getURL: ->
    @href || [@_type.getURL(), @id].join '/'

  toJSON: ->
    result = {}
    result[@_type.name] = {}
    for own key, value of this when key.charAt(0) isnt '_' and key not in @_readOnlyKeys
      result[@_type.name][key] = value
    result
