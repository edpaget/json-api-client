Emitter = require './emitter'
mergeInto = require './merge-into'

isIndex = (string) ->
  integer = Math.abs parseInt string, 10
  integer.toString(10) is string and not isNaN integer

module.exports = class Model extends Emitter
  _changedKeys: null

  constructor: (configs...) ->
    super
    @_changedKeys = []
    mergeInto this, configs...
    @emit 'create'

  update: (changeSet = {}) ->
    if typeof changeSet is 'string'
      for key in arguments when key not in @_changedKeys
        @_changedKeys.push arguments...
    else
      for own key, value of changeSet
        path = key.split '.'
        rootKey = path[0]
        base = this
        until path.length is 1
          base[path[0]] ?= if isIndex path[0]
            []
          else
            {}

          base = base[path.shift()]
        lastKey = path.shift()
        if value is undefined
          delete base[lastKey]
        else
          base[lastKey] = value
        unless rootKey in @_changedKeys
          @_changedKeys.push rootKey
    @emit 'change'
    this

  hasUnsavedChanges: ->
    @_changedKeys.length isnt 0
